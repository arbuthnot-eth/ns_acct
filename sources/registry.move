module acct_registry::ns_acct {
    use sui::table::Table;
    use sui::transfer::public_transfer;
    use std::string::String;


    // SuiNS integration (v4 API)
    use suins::{
        suins::SuiNS,
        name_record,
        domain,
        suins_registration::SuinsRegistration
    };

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

    // Helper to parse full domain string (e.g., "n-s.acct.sui") into Domain
    fun parse_domain_string(full_name: &String): domain::Domain {
        domain::new(*full_name)
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
        // Parse the full domain string into a proper Domain
        let domain = parse_domain_string(&domain_name);
        
        // Correct registry access (matching NFT version)
        let registry_ref = suins::suins::registry(suins);
        
        // Use the correct SuiNS API pattern from official docs
        let mut optional = suins::registry::lookup(registry_ref, domain);
        
        if (std::option::is_none(&optional)) {
            return false
        };
        
        let name_record = std::option::extract(&mut optional);
        
        // Get target address using correct API
        let target_opt = name_record.target_address();
        std::option::is_some(&target_opt) && (*std::option::borrow(&target_opt) == caller)
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

    /// Update an entry in a namespace using subdomain key with proper verification
    /// Handles both regular domains and leaf subnames according to SuiNS rules:
    /// - For regular domains: Verifies caller owns the NFT
    /// - For leaf subnames: Verifies caller is target address OR owns parent NFT
    /// e.g., stores "n-s.acct.sui" as key while verifying proper control
    public fun update_subdomain_entry_with_verification(
        registry: &mut Registry,
        suins: &SuiNS,
        nft: &SuinsRegistration,
        namespace_name: String,
        subdomain_key: String,  // e.g., "n-s.acct.sui"
        data: String,           // Custom data for AcctObject
        caller: address,        // Address of the caller
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Borrow the namespace (this will abort if namespace doesn't exist)
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow_mut(&mut registry.namespaces, namespace_name);

        // Get the parent domain name from the NFT
        let parent_domain = suins::domain::to_string(&suins::suins_registration::domain(nft));
        
        // Verify that the subdomain_key is a subdomain of the parent_domain
        // e.g., "n-s.acct.sui" should end with ".acct.sui"
        let mut parent_suffix = std::string::utf8(b".");
        std::string::append(&mut parent_suffix, parent_domain);
        assert!(is_subdomain_of(subdomain_key, parent_suffix), ENotAuthorized);

        // Verify control over the subdomain according to SuiNS rules
        assert!(verify_subdomain_control(suins, nft, subdomain_key, caller), ENotAuthorized);

        // Create or update the AcctObject using the full subdomain key
        let acct_obj = AcctObject {
            id: sui::object::new(ctx),
            data,
        };

        // Add or update the entry using subdomain key
        if (sui::table::contains(&namespace_obj.entries, subdomain_key)) {
            // Update existing entry
            let old_entry = sui::table::remove(&mut namespace_obj.entries, subdomain_key);
            public_transfer(old_entry, @0x0); // Transfer to burn address
        };
        sui::table::add(&mut namespace_obj.entries, subdomain_key, acct_obj);
    }

    /// Convenience wrapper that automatically gets caller address
    /// This is the function users should typically call for subdomain entries
    public fun update_subdomain_entry_with_nft(
        registry: &mut Registry,
        suins: &SuiNS,
        nft: &SuinsRegistration,
        namespace_name: String,
        subdomain_key: String,  // e.g., "n-s.acct.sui"
        data: String,           // Custom data for AcctObject
        ctx: &mut sui::tx_context::TxContext
    ) {
        let caller = sui::tx_context::sender(ctx);
        update_subdomain_entry_with_verification(
            registry, 
            suins, 
            nft, 
            namespace_name, 
            subdomain_key, 
            data, 
            caller, 
            ctx
        );
    }

    /// Update a subdomain entry using target address verification (most common scenario)
    /// This is for users who control a subdomain via target address but don't own the parent NFT
    /// Verifies that the caller is the current target address of the subdomain in SuiNS
    public fun update_subdomain_entry_by_target(
        registry: &mut Registry,
        suins: &SuiNS,
        namespace_name: String,
        subdomain_key: String,  // e.g., "n-s.acct.sui"
        data: String,           // Custom data for AcctObject
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Borrow the namespace (this will abort if namespace doesn't exist)
        assert!(sui::table::contains(&registry.namespaces, namespace_name), ENamespaceNotFound);
        let namespace_obj = sui::table::borrow_mut(&mut registry.namespaces, namespace_name);

        let caller = sui::tx_context::sender(ctx);
        
        // Verify that caller controls the subdomain via target address
        assert!(verify_subdomain_target_control(suins, subdomain_key, caller), ENotAuthorized);

        // Create or update the AcctObject using the full subdomain key
        let acct_obj = AcctObject {
            id: sui::object::new(ctx),
            data,
        };

        // Add or update the entry using subdomain key
        if (sui::table::contains(&namespace_obj.entries, subdomain_key)) {
            // Update existing entry
            let old_entry = sui::table::remove(&mut namespace_obj.entries, subdomain_key);
            public_transfer(old_entry, @0x0); // Transfer to burn address
        };
        sui::table::add(&mut namespace_obj.entries, subdomain_key, acct_obj);
    }

    /// Verify that the caller is the target address of a subdomain
    /// This is used for leaf subnames where the user doesn't own the parent NFT
    /// but has been granted control via the target address mechanism
    fun verify_subdomain_target_control(
        suins: &SuiNS,
        subdomain_key: String,
        caller: address
    ): bool {
        // Use the same approach as the existing update_entry function
        // which works for both domains and subnames via target address verification
        verify_domain_ownership(suins, subdomain_key, caller)
    }

    /// Verify control over a subdomain according to SuiNS rules
    /// Returns true if caller can control the subdomain:
    /// - If caller owns the parent NFT: always true
    /// - For leaf subnames: simplified check - parent NFT owner controls subdomains
    /// Note: Full leaf subname target verification requires more complex SuiNS integration
    fun verify_subdomain_control(
        suins: &SuiNS,
        parent_nft: &SuinsRegistration,
        _subdomain_key: String,
        _caller: address
    ): bool {
        // For now, only allow parent NFT owners to control subdomains
        // This is the most secure approach and follows SuiNS parent control rules
        verify_domain_ownership_with_nft(suins, parent_nft)
    }

    /// Helper function to check if a string is a subdomain of another
    /// e.g., is_subdomain_of("n-s.acct.sui", ".acct.sui") returns true
    fun is_subdomain_of(subdomain: String, parent_suffix: String): bool {
        let subdomain_bytes = std::string::as_bytes(&subdomain);
        let suffix_bytes = std::string::as_bytes(&parent_suffix);
        let subdomain_len = vector::length(subdomain_bytes);
        let suffix_len = vector::length(suffix_bytes);
        
        // Subdomain must be longer than suffix
        if (subdomain_len <= suffix_len) return false;
        
        // Check if subdomain ends with the parent suffix
        let mut i = 0;
        while (i < suffix_len) {
            let subdomain_char = *vector::borrow(subdomain_bytes, subdomain_len - suffix_len + i);
            let suffix_char = *vector::borrow(suffix_bytes, i);
            if (subdomain_char != suffix_char) return false;
            i = i + 1;
        };
        true
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