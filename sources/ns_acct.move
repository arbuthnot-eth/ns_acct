module ns_acct::ns_acct {
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self, String};
    
    // SuiNS core modules
    use suins::suins_registration::{Self, SuinsRegistration};
    use suins::domain;

    /// Error codes
    const EMismatch: u64 = 0;
    // const ENotParentDomain: u64 = 1;
    const ESubdomainAlreadyExists: u64 = 2;
    // const EInvalidSubdomain: u64 = 3;

    /// Capability for account creation, tied to a specific user domain
    public struct AccountCap has key, store {
        id: object::UID,
        reg_id: object::ID,  // Matches the user's SuinsRegistration ID
    }

    /// Capability for subdomain creation under a parent domain
    public struct SubdomainCap has key, store {
        id: object::UID,
        parent_reg_id: object::ID,  // ID of the parent domain registration
        parent_domain: String,      // Parent domain name (e.g., "acct.sui")
    }

    /// The Acct object, linked to a specific SuiNS domain
    public struct Acct has key, store {
        id: object::UID,
        reg_id: object::ID,
        domain_name: String,           // Store the domain name for reference
        is_subdomain: bool,            // Whether this is a subdomain account
        parent_domain: option::Option<String>, // Parent domain if this is a subdomain
        value: u64,                    // Example static field
        extra_fields: VecMap<String, String>,  // Dynamic fields
        subdomain_registry: VecMap<String, object::ID>, // Track created subdomains
    }

    /// Request an AccountCap by proving ownership of a .sui domain
    #[allow(lint(self_transfer))]
    public fun request_cap(user_reg: &SuinsRegistration, ctx: &mut tx_context::TxContext) {
        let cap = AccountCap {
            id: object::new(ctx),
            reg_id: object::id(user_reg),
        };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    /// Request a SubdomainCap for creating subdomains under a parent domain
    #[allow(lint(self_transfer))]
    public fun request_subdomain_cap(
        parent_reg: &SuinsRegistration, 
        ctx: &mut tx_context::TxContext
    ) {
        let parent_domain = suins_registration::domain(parent_reg);
        let parent_domain_str = domain::to_string(&parent_domain);
        
        let cap = SubdomainCap {
            id: object::new(ctx),
            parent_reg_id: object::id(parent_reg),
            parent_domain: parent_domain_str,
        };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    /// Create a custom subdomain account (e.g., "n-s.acct.sui")
    public fun create_custom_subdomain(
        parent_reg: &SuinsRegistration,
        subdomain_cap: SubdomainCap,
        custom_name: String,
        ctx: &mut tx_context::TxContext
    ): object::ID {
        // Validate cap matches parent registration
        assert!(subdomain_cap.parent_reg_id == object::id(parent_reg), EMismatch);
        
        let SubdomainCap { 
            id: cap_id, 
            parent_reg_id: _, 
            parent_domain 
        } = subdomain_cap;
        object::delete(cap_id);  // Consume cap

        // Create full subdomain name (e.g., "n-s.acct.sui")
        let mut full_subdomain = string::utf8(b"");
        string::append(&mut full_subdomain, custom_name);
        string::append_utf8(&mut full_subdomain, b".");
        string::append(&mut full_subdomain, parent_domain);

        // Create subdomain account linked to parent registration
        let acct = Acct {
            id: object::new(ctx),
            reg_id: object::id(parent_reg),
            domain_name: full_subdomain,
            value: 0,
            extra_fields: vec_map::empty(),
            is_subdomain: true,
            parent_domain: option::some(parent_domain),
            subdomain_registry: vec_map::empty(),
        };

        let acct_id = object::id(&acct);
        transfer::public_share_object(acct);
        acct_id
    }

    /// Create shared Acct using domain ownership proof
    public fun create_account(
        user_reg: &SuinsRegistration,
        cap: AccountCap,
        ctx: &mut tx_context::TxContext
    ) {
        // Validate cap matches user_reg
        assert!(cap.reg_id == object::id(user_reg), EMismatch);
        let reg_id = cap.reg_id;
        let AccountCap { id: cap_id, reg_id: _ } = cap;
        object::delete(cap_id);  // Consume cap

        // Extract domain name for storage
        let user_domain = suins_registration::domain(user_reg);
        let domain_name = domain::to_string(&user_domain);

        // Create Acct with domain info
        let acct = Acct {
            id: object::new(ctx),
            reg_id,
            domain_name,
            is_subdomain: false,
            parent_domain: option::none(),
            value: 0,
            extra_fields: vec_map::empty(),
            subdomain_registry: vec_map::empty(),
        };
        
        transfer::share_object(acct);
    }

    /// Create a subdomain under the namespace service account (e.g., bob.n-s.acct.sui)
    /// The namespace_acct is the n-s.acct.sui account object
    public fun create_user_subdomain(
        namespace_acct: &Acct,           // The n-s.acct.sui namespace service account
        user_reg: &SuinsRegistration,    // The bob.sui user registration  
        subdomain_cap: SubdomainCap,     // Cap proving namespace ownership
        ctx: &mut tx_context::TxContext
    ): object::ID {
        // Validate the namespace account is actually a subdomain (n-s.acct.sui)
        assert!(namespace_acct.is_subdomain, EMismatch);
        
        // Validate cap matches the original parent registration (acct.sui)
        assert!(subdomain_cap.parent_reg_id == namespace_acct.reg_id, EMismatch);
        
        let SubdomainCap { 
            id: cap_id, 
            parent_reg_id: _, 
            parent_domain: _ 
        } = subdomain_cap;
        object::delete(cap_id);  // Consume cap

        // Extract the user's domain name (e.g., "bob.sui")
        let user_domain = suins_registration::domain(user_reg);
        let user_domain_str = domain::to_string(&user_domain);
        
        // Extract just the name part (bob from bob.sui)
        let user_name = extract_name_from_domain(user_domain_str);

        // Create full subdomain name under namespace (e.g., "bob.n-s.acct.sui")
        let mut full_subdomain = string::utf8(b"");
        string::append(&mut full_subdomain, user_name);
        string::append_utf8(&mut full_subdomain, b".");
        string::append(&mut full_subdomain, namespace_acct.domain_name);

        // Create subdomain account linked to user's registration
        let subdomain_acct = Acct {
            id: object::new(ctx),
            reg_id: object::id(user_reg), // Links to user's domain registration!
            domain_name: full_subdomain,
            is_subdomain: true,
            parent_domain: option::some(namespace_acct.domain_name),
            value: 0,
            extra_fields: vec_map::empty(),
            subdomain_registry: vec_map::empty(),
        };
        
        let acct_id = object::id(&subdomain_acct);
        transfer::share_object(subdomain_acct);
        acct_id
    }

    /// Helper function to extract name from domain (alice from alice.sui)
    fun extract_name_from_domain(domain_str: String): String {
        let domain_bytes = string::as_bytes(&domain_str);
        let len = vector::length(domain_bytes);
        let mut name_bytes = vector::empty<u8>();
        
        let mut i = 0;
        while (i < len) {
            let byte = *vector::borrow(domain_bytes, i);
            if (byte == 46) { // ASCII for '.'
                break
            };
            vector::push_back(&mut name_bytes, byte);
            i = i + 1;
        };
        
        string::utf8(name_bytes)
    }

    /// Register a cross-domain subdomain in the parent account's registry
    /// Register a user subdomain in the namespace service registry
    public fun register_user_subdomain(
        user_reg: &SuinsRegistration,       // bob.sui registration  
        namespace_acct: &mut Acct,          // n-s.acct.sui namespace account
        subdomain_acct_id: object::ID       // bob.n-s.acct.sui account ID
    ) {
        // Validate the namespace account is a subdomain
        assert!(namespace_acct.is_subdomain, EMismatch);
        
        // Extract user domain name to use as subdomain key
        let user_domain = suins_registration::domain(user_reg);
        let user_domain_str = domain::to_string(&user_domain);
        let user_name = extract_name_from_domain(user_domain_str);
        
        // Check subdomain doesn't already exist
        assert!(!vec_map::contains(&namespace_acct.subdomain_registry, &user_name), ESubdomainAlreadyExists);
        
        // Register the subdomain in the namespace service
        vec_map::insert(&mut namespace_acct.subdomain_registry, user_name, subdomain_acct_id);
    }

    /// Register a subdomain in the parent account's registry (original function)
    public fun register_subdomain_in_parent(
        parent_reg: &SuinsRegistration,
        parent_acct: &mut Acct,
        subdomain_name: String,
        subdomain_acct_id: object::ID
    ) {
        // Validate ownership of parent domain
        assert!(parent_acct.reg_id == object::id(parent_reg), EMismatch);
        
        // Check subdomain doesn't already exist
        assert!(!vec_map::contains(&parent_acct.subdomain_registry, &subdomain_name), ESubdomainAlreadyExists);
        
        // Register the subdomain
        vec_map::insert(&mut parent_acct.subdomain_registry, subdomain_name, subdomain_acct_id);
    }

    /// Update static value field; gated by user_reg (works for both regular and subdomain accounts)
    public fun update_value(user_reg: &SuinsRegistration, acct: &mut Acct, new_value: u64) {
        assert!(acct.reg_id == object::id(user_reg), EMismatch);
        acct.value = new_value;
    }

    /// Add a dynamic field (works for both regular and subdomain accounts)
    public fun add_field(user_reg: &SuinsRegistration, acct: &mut Acct, key: String, val: String) {
        assert!(acct.reg_id == object::id(user_reg), EMismatch);
        vec_map::insert(&mut acct.extra_fields, key, val);
    }

    /// Delete a dynamic field by key
    public fun delete_field(user_reg: &SuinsRegistration, acct: &mut Acct, key: String) {
        assert!(acct.reg_id == object::id(user_reg), EMismatch);
        if (vec_map::contains(&acct.extra_fields, &key)) {
            vec_map::remove(&mut acct.extra_fields, &key);
        }
    }

    // Public getters
    public fun domain_name(acct: &Acct): String {
        acct.domain_name
    }

    public fun value(acct: &Acct): u64 {
        acct.value
    }

    public fun is_subdomain(acct: &Acct): bool {
        acct.is_subdomain
    }

    public fun parent_domain(acct: &Acct): option::Option<String> {
        acct.parent_domain
    }

    public fun get_field(acct: &Acct, key: String): option::Option<String> {
        if (vec_map::contains(&acct.extra_fields, &key)) {
            option::some(*vec_map::get(&acct.extra_fields, &key))
        } else {
            option::none()
        }
    }

    public fun reg_id(acct: &Acct): object::ID {
        acct.reg_id
    }

    public fun extra_fields(acct: &Acct): &VecMap<String, String> {
        &acct.extra_fields
    }

    public fun subdomain_registry(acct: &Acct): &VecMap<String, object::ID> {
        &acct.subdomain_registry
    }

    public fun get_subdomain_account_id(parent_acct: &Acct, subdomain_name: String): option::Option<object::ID> {
        if (vec_map::contains(&parent_acct.subdomain_registry, &subdomain_name)) {
            option::some(*vec_map::get(&parent_acct.subdomain_registry, &subdomain_name))
        } else {
            option::none()
        }
    }

    // Helper functions for testing
    public fun extra_fields_length(acct: &Acct): u64 {
        vec_map::size(&acct.extra_fields)
    }

    public fun subdomain_count(acct: &Acct): u64 {
        vec_map::size(&acct.subdomain_registry)
    }

    // Test helper function to create an Acct for testing
    #[test_only]
    public fun create_test_acct(
        reg_id: object::ID,
        domain_name: String,
        value: u64,
        ctx: &mut tx_context::TxContext
    ): Acct {
        Acct {
            id: object::new(ctx),
            reg_id,
            domain_name,
            is_subdomain: false,
            parent_domain: option::none(),
            value,
            extra_fields: vec_map::empty(),
            subdomain_registry: vec_map::empty(),
        }
    }

    // Test helper function to add a field for testing
    #[test_only]
    public fun add_test_field(acct: &mut Acct, key: String, val: String) {
        vec_map::insert(&mut acct.extra_fields, key, val);
    }
}
