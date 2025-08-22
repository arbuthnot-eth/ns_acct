module acct_registry::ns_acct {
    use sui::table::Table;
    use sui::transfer::public_transfer;
    use std::string::String;

    // SuiNS integration (v4 API)
    use suins::suins::SuiNS;
    use suins::registry;
    use suins::name_record;
    use suins::suins_registration::SuinsRegistration;

    /// Error codes
    const ENotAuthorized: u64 = 0;
    const ENamespaceNotFound: u64 = 1;
    const EEntryNotFound: u64 = 3;

    /// Top-level Registry object, holding a table of namespaces
    public struct Registry has key {
        id: sui::object::UID,
        namespaces: Table<String, Namespace>, // e.g., "ns" -> Namespace object
        owner: address,  // Address that owns this registry
    }

    /// Namespace object, managing a specific namespace like "ns"
    public struct Namespace has key, store {
        id: sui::object::UID,
        name: String, // e.g., "ns"
        entries: Table<String, AcctObject>, // Maps .sui name (e.g., "domain.sui") to AcctObject
    }

    /// Custom AcctObject stored in Namespace entries
    public struct AcctObject has key, store {
        id: sui::object::UID,
        data: String, // Custom metadata or payload
    }

    // Registry Functions

    /// Initialize the Registry (call once, owned by acct.sui's address)
    public fun init_registry(ctx: &mut tx_context::TxContext): Registry {
        Registry {
            id: sui::object::new(ctx),
            namespaces: sui::table::new(ctx),
            owner: sui::tx_context::sender(ctx),
        }
    }

    /// Create and transfer a Registry to the caller
    entry fun create_registry(ctx: &mut tx_context::TxContext) {
        let registry = init_registry(ctx);
        sui::transfer::transfer(registry, sui::tx_context::sender(ctx));
    }

    /// Add a new namespace (e.g., "ns" or "phone-numbers")
    /// Restricted to the registry owner
    public fun add_namespace(
        registry: &mut Registry,
        namespace_name: String,
        caller: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Verify caller is the registry owner
        assert!(caller == registry.owner, ENotAuthorized);

        let namespace_obj = Namespace {
            id: sui::object::new(ctx),
            name: namespace_name,
            entries: sui::table::new(ctx),
        };
        sui::table::add(&mut registry.namespaces, namespace_name, namespace_obj);
    }

    /// Verify domain ownership using the SuiNS NFT object (preferred method)
    /// This is the most secure approach as it verifies actual NFT ownership
    public fun verify_domain_ownership_with_nft(
        suins: &SuiNS,
        nft: &SuinsRegistration
    ): bool {
        // Get the SuiNS registry from SuiNS object
        let registry_ref = suins::suins::registry(suins);
        
        // Get the domain from NFT and verify it exists in registry
        let domain = suins::suins_registration::domain(nft);
        let record_option = suins::registry::lookup(registry_ref, domain);
        
        if (std::option::is_none(&record_option)) {
            return false
        };
        
        let record = std::option::borrow(&record_option);
        
        // Verify the NFT ID matches the registry record
        let nft_id = sui::object::id(nft);
        name_record::nft_id(record) == nft_id
    }

    /// Verify domain ownership by target address (fallback method)
    /// Less secure but works for cases where NFT access isn't available
    /// Handles two cases:
    /// 1. Domain registration: caller is the target address
    /// 2. Leaf subname: caller is the target address of a leaf subname
    public fun verify_domain_ownership(
        suins: &SuiNS,
        domain_name: String,
        caller: address
    ): bool {
        // Convert string to domain using SuiNS domain::new
        let domain = suins::domain::new(domain_name);
        
        // Get the SuiNS registry from SuiNS object
        let registry_ref = suins::suins::registry(suins);
        
        // Look up the name record
        let record_option = registry::lookup(registry_ref, domain);
        
        if (std::option::is_none(&record_option)) {
            return false
        };
        
        let record = std::option::borrow(&record_option);
        
        // For both leaf records and regular domains, check target address
        let target = name_record::target_address(record);
        std::option::is_some(&target) && (*std::option::borrow(&target) == caller)
    }

    /// Update an entry in a namespace using NFT verification (preferred method)
    /// Most secure as it requires the actual SuiNS NFT for parent domains
    /// Note: This only works for parent domains that have NFTs, not leaf subnames
    public fun update_entry_with_nft(
        registry: &mut Registry,
        suins: &SuiNS,
        nft: &SuinsRegistration,
        namespace_name: String,
        data: String,      // Custom data for AcctObject
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Borrow the namespace (this will abort if namespace doesn't exist)
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow_mut(&mut registry.namespaces, namespace_name);

        // Verify caller owns the domain via SuiNS NFT
        assert!(verify_domain_ownership_with_nft(suins, nft), ENotAuthorized);
        
        // Get the domain name from the NFT
        let key = suins::domain::to_string(&suins::suins_registration::domain(nft));

        // Create or update the AcctObject
        let acct_obj = AcctObject {
            id: sui::object::new(ctx),
            data,
        };

        // Add or update the entry
        if (sui::table::contains(&namespace_obj.entries, key)) {
            // Update existing entry
            let old_entry = sui::table::remove(&mut namespace_obj.entries, key);
            public_transfer(old_entry, @0x0); // Transfer to burn address
        };
        sui::table::add(&mut namespace_obj.entries, key, acct_obj);
    }


    /// Update an entry in a namespace (works for both domains and subnames)
    /// Verifies caller owns the .sui key via target address check
    /// Handles both parent domains and leaf subnames
    public fun update_entry(
        registry: &mut Registry,
        suins: &SuiNS,
        namespace_name: String,
        key: String,       // e.g., "domain.sui"
        data: String,      // Custom data for AcctObject
        caller: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Borrow the namespace (this will abort if namespace doesn't exist)
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow_mut(&mut registry.namespaces, namespace_name);

        // Verify caller owns the domain via SuiNS
        assert!(verify_domain_ownership(suins, key, caller), ENotAuthorized);

        // Create or update the AcctObject
        let acct_obj = AcctObject {
            id: sui::object::new(ctx),
            data,
        };

        // Add or update the entry
        if (sui::table::contains(&namespace_obj.entries, key)) {
            // Update existing entry
            let old_entry = sui::table::remove(&mut namespace_obj.entries, key);
            public_transfer(old_entry, @0x0); // Transfer to burn address
        };
        sui::table::add(&mut namespace_obj.entries, key, acct_obj);
    }

    /// Query an AcctObject from a namespace (e.g., get AcctObject for "domain.sui" in "ns")
    public fun query(
        registry: &Registry,
        namespace_name: String,
        key: String
    ): &AcctObject {
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow(&registry.namespaces, namespace_name);
        assert!(sui::table::contains(&namespace_obj.entries, key), EEntryNotFound);
        sui::table::borrow(&namespace_obj.entries, key)
    }

    /// Remove an entry from a namespace
    public fun remove_entry(
        registry: &mut Registry,
        suins: &SuiNS,
        namespace_name: String,
        key: String,
        caller: address
    ) {
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow_mut(&mut registry.namespaces, namespace_name);

        assert!(sui::table::contains(&namespace_obj.entries, key), EEntryNotFound);
        let _entry = sui::table::borrow(&namespace_obj.entries, key);

        // Verify caller owns the domain via SuiNS
        assert!(verify_domain_ownership(suins, key, caller), ENotAuthorized);

        let removed_entry = sui::table::remove(&mut namespace_obj.entries, key);
        public_transfer(removed_entry, @0x0); // Transfer to burn address
    }

    /// Create an AcctObject directly (helper function)
    public fun create_acct_object(
        data: String,
        ctx: &mut sui::tx_context::TxContext
    ): AcctObject {
        AcctObject {
            id: sui::object::new(ctx),
            data,
        }
    }

    // Getter Functions

    /// Get registry owner
    public fun registry_owner(registry: &Registry): address {
        registry.owner
    }

    /// Check if namespace exists
    public fun namespace_exists(registry: &Registry, namespace_name: String): bool {
        sui::table::contains(&registry.namespaces, namespace_name)
    }

    /// Get namespace name
    public fun namespace_name(namespace: &Namespace): String {
        namespace.name
    }



    /// Get AcctObject data
    public fun acct_data(acct: &AcctObject): String {
        acct.data
    }





    /// External query function that returns copyable data instead of references
    /// This can be called from transactions and returns the account data
    /// Note: Owner and target information should be queried from SuiNS directly
    public fun get_account_data(
        registry: &Registry,
        namespace_name: String,
        key: String
    ): (String, String) {
        let acct = query(registry, namespace_name, key);
        (key, acct.data)  // Return the key parameter since it's not stored in the object
    }
}
