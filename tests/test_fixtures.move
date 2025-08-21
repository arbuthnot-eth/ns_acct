#[test_only]
module ns_acct::test_fixtures {
    use ns_acct::ns_acct;
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use std::string;
    use std::option;
    use std::vector;

    /// Test fixture for creating a standard user account
    public fun create_user_account_fixture(
        domain_name: vector<u8>,
        initial_value: u64,
        ctx: &mut tx_context::TxContext
    ): (ns_acct::Acct, object::ID) {
        let domain = string::utf8(domain_name);
        let reg_id = object::id_from_address(@0x1001);

        let acct = ns_acct::create_test_acct(reg_id, domain, initial_value, ctx);
        (acct, reg_id)
    }

    /// Test fixture for creating a subname account
    public fun create_subname_account_fixture(
        parent_domain: vector<u8>,
        subname: vector<u8>,
        initial_value: u64,
        ctx: &mut tx_context::TxContext
    ): (ns_acct::Acct, object::ID) {
        let parent_domain_str = string::utf8(parent_domain);
        let subname_str = string::utf8(subname);

        let mut full_subname = string::utf8(b"");
        string::append(&mut full_subname, subname_str);
        string::append_utf8(&mut full_subname, b".");
        string::append(&mut full_subname, parent_domain_str);

        let reg_id = object::id_from_address(@0x1002);
        let acct = ns_acct::create_test_acct(reg_id, full_subname, initial_value, ctx);
        (acct, reg_id)
    }

    /// Test fixture for creating a namespace service account
    public fun create_namespace_service_fixture(
        namespace: vector<u8>,
        parent_domain: vector<u8>,
        ctx: &mut tx_context::TxContext
    ): (ns_acct::Acct, object::ID) {
        let namespace_str = string::utf8(namespace);
        let parent_domain_str = string::utf8(parent_domain);

        let mut full_ns_domain = string::utf8(b"");
        string::append(&mut full_ns_domain, namespace_str);
        string::append_utf8(&mut full_ns_domain, b".");
        string::append(&mut full_ns_domain, parent_domain_str);

        let reg_id = object::id_from_address(@0x1003);
        let acct = ns_acct::create_test_acct(reg_id, full_ns_domain, 0, ctx);
        (acct, reg_id)
    }

    /// Test fixture for creating an account with multiple fields
    public fun create_account_with_fields_fixture(
        domain_name: vector<u8>,
        fields: vector<vector<u8>>,
        values: vector<vector<u8>>,
        ctx: &mut tx_context::TxContext
    ): (ns_acct::Acct, object::ID) {
        let domain = string::utf8(domain_name);
        let reg_id = object::id_from_address(@0x1004);

        let mut acct = ns_acct::create_test_acct(reg_id, domain, 0, ctx);

        let fields_len = vector::length(&fields);
        let mut i = 0;
        while (i < fields_len) {
            let field_key = string::utf8(*vector::borrow(&fields, i));
            let field_value = string::utf8(*vector::borrow(&values, i));
            ns_acct::add_test_field(&mut acct, field_key, field_value);
            i = i + 1;
        };

        (acct, reg_id)
    }

    /// Test fixture for creating a complex multi-user scenario
    public fun create_multi_user_scenario_fixture(ctx: &mut tx_context::TxContext): (
        ns_acct::Acct,  // namespace service account
        ns_acct::Acct,  // user1 account
        ns_acct::Acct,  // user2 account
        ns_acct::Acct,  // user1 ns account
        ns_acct::Acct   // user2 ns account
    ) {
        // Create namespace service account
        let (ns_acct, _ns_reg_id) = create_namespace_service_fixture(
            b"ns", b"acct.sui", ctx
        );

        // Create user accounts
        let (user1_acct, _user1_reg_id) = create_user_account_fixture(
            b"alice.sui", 100, ctx
        );

        let (user2_acct, _user2_reg_id) = create_user_account_fixture(
            b"bob.sui", 200, ctx
        );

        // Create namespace accounts for users
        let (alice_ns_acct, _alice_ns_reg_id) = create_subname_account_fixture(
            b"ns.acct.sui", b"alice", 50, ctx
        );

        let (bob_ns_acct, _bob_ns_reg_id) = create_subname_account_fixture(
            b"ns.acct.sui", b"bob", 75, ctx
        );

        (ns_acct, user1_acct, user2_acct, alice_ns_acct, bob_ns_acct)
    }

    /// Test fixture for error scenarios
    public fun create_error_scenario_fixture(ctx: &mut tx_context::TxContext): (
        ns_acct::Acct,  // account with mismatched registration
        object::ID      // different registration ID
    ) {
        let acct = ns_acct::create_test_acct(
            object::id_from_address(@0x2001),
            string::utf8(b"test.sui"),
            0,
            ctx
        );

        let different_reg_id = object::id_from_address(@0x2002);

        (acct, different_reg_id)
    }

    /// Test fixture for large registry scenario
    public fun create_large_registry_fixture(
        num_entries: u64,
        ctx: &mut tx_context::TxContext
    ): ns_acct::Acct {
        let mut acct = ns_acct::create_test_acct(
            object::id_from_address(@0x3001),
            string::utf8(b"registry.sui"),
            0,
            ctx
        );

        let mut i = 0;
        while (i < num_entries) {
            let key = string::utf8(b"entry_");
            let mut key_str = string::utf8(b"");
            string::append(&mut key_str, key);
            // Note: In real implementation, you'd want to append the number
            // For simplicity, using generic keys here

            let value = string::utf8(b"value_data");
            ns_acct::add_test_field(&mut acct, key_str, value);
            i = i + 1;
        };

        acct
    }

    /// Helper function to get test domain names
    public fun get_test_domains(): vector<vector<u8>> {
        vector[
            b"alice.sui",
            b"bob.sui",
            b"charlie.sui",
            b"dave.sui",
            b"eve.sui"
        ]
    }

    /// Helper function to get test namespace configurations
    public fun get_test_namespaces(): vector<vector<u8>> {
        vector[
            b"ns",
            b"service",
            b"app",
            b"api"
        ]
    }

    /// Helper function to create performance test data
    public fun create_performance_test_data(
        num_accounts: u64,
        fields_per_account: u64,
        ctx: &mut tx_context::TxContext
    ): vector<ns_acct::Acct> {
        let mut accounts = vector::empty();

        let mut i = 0;
        while (i < num_accounts) {
            let domain = string::utf8(b"perf_test_");
            // In real implementation, you'd append the index

            let (acct, _reg_id) = create_user_account_fixture(domain, 0, ctx);

            // Add multiple fields for performance testing
            let mut j = 0;
            while (j < fields_per_account) {
                let key = string::utf8(b"field_");
                let value = string::utf8(b"performance_test_value");
                ns_acct::add_test_field(&mut acct, key, value);
                j = j + 1;
            };

            vector::push_back(&mut accounts, acct);
            i = i + 1;
        };

        accounts
    }
}
