module ns_acct::ns_acct {
    use sui::vec_map::{Self, VecMap};
    use std::string::String;
    
    // SuiNS core modules only
    use suins::suins_registration::{Self, SuinsRegistration};
    use suins::domain;
    use suins::suins::SuiNS;

    /// Error codes
    const EMismatch: u64 = 0;
    const EInvalidDomain: u64 = 1;

    /// Capability for account creation, tied to a specific user domain
    public struct AccountCap has key, store {
        id: object::UID,
        reg_id: object::ID,  // Matches the user's SuinsRegistration ID
    }

    /// The Acct object, linked to a specific SuiNS domain
    public struct Acct has key, store {
        id: object::UID,
        reg_id: object::ID,
        domain_name: String,           // Store the domain name for reference
        value: u64,                    // Example static field
        extra_fields: VecMap<String, String>,  // Dynamic fields
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
            value: 0,
            extra_fields: vec_map::empty(),
        };
        
        transfer::share_object(acct);
    }

    /// Update static value field; gated by user_reg
    public fun update_value(user_reg: &SuinsRegistration, acct: &mut Acct, new_value: u64) {
        assert!(acct.reg_id == object::id(user_reg), EMismatch);
        acct.value = new_value;
    }

    /// Add a dynamic field (e.g., key="metadata", value="new data")
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

    // Helper functions for testing
    public fun extra_fields_length(acct: &Acct): u64 {
        vec_map::size(&acct.extra_fields)
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
            value,
            extra_fields: vec_map::empty(),
        }
    }

    // Test helper function to add a field for testing
    #[test_only]
    public fun add_test_field(acct: &mut Acct, key: String, val: String) {
        vec_map::insert(&mut acct.extra_fields, key, val);
    }
}
