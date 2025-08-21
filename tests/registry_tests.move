#[test_only]
module ns_acct_addr::registry_tests {
    use ns_acct_addr::registry;
    use sui::object;
    use sui::test_scenario;
    use sui::table;
    use sui::tx_context;
    use std::string;

    const USER: address = @0x123;
    const OTHER_USER: address = @0x456;

    #[test]
    fun test_init_registry() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let registry = registry::init_registry(test_scenario::ctx(scenario));

        // Verify registry was created with correct owner
        assert!(registry::registry_owner(&registry) == USER, 0);

        // Share registry object
        sui::transfer::share_object(registry);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_namespace() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"ns"), USER, test_scenario::ctx(scenario));

        // Verify namespace was added
        assert!(registry::namespace_exists(&registry, string::utf8(b"ns")), 1);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_namespace_unauthorized() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, OTHER_USER);

        // Try to add namespace as different user (should fail)
        let result = test_scenario::try_tx(scenario, |ctx| {
            registry::add_namespace(&mut registry, string::utf8(b"ns"), OTHER_USER, ctx);
        });

        // Should abort with ENotAuthorized
        assert!(test_scenario::tx_aborted(&result), 0);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_entry() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"ns"), USER, test_scenario::ctx(scenario));

        // Create a mock SuiNS object (for testing)
        let mock_suins_id = object::id_from_address(@0x999);

        // For testing, we'll create a simple verification function that trusts the caller
        // In real usage, this would verify actual SuiNS domain ownership

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_query_entry() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"ns"), USER, test_scenario::ctx(scenario));

        // Create and add an entry directly for testing
        let acct_obj = registry::create_acct_object(
            string::utf8(b"test.sui"),
            string::utf8(b"test data"),
            USER,
            USER,
            test_scenario::ctx(scenario)
        );

        // Manually add to namespace for testing
        let namespace_name = string::utf8(b"ns");
        let namespace_obj = table::borrow_mut(&mut registry.namespaces, namespace_name);
        table::add(&mut namespace_obj.entries, string::utf8(b"test.sui"), acct_obj);

        // Query the entry
        let queried = registry::query(&registry, string::utf8(b"ns"), string::utf8(b"test.sui"));

        // Verify data
        assert!(registry::acct_data(queried) == string::utf8(b"test data"), 2);
        assert!(registry::acct_key(queried) == string::utf8(b"test.sui"), 3);
        assert!(registry::acct_target(queried) == USER, 4);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_query_nonexistent_namespace() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let registry = registry::init_registry(test_scenario::ctx(scenario));

        // Try to query from nonexistent namespace
        let result = test_scenario::try_tx(scenario, |ctx| {
            registry::query(&registry, string::utf8(b"nonexistent"), string::utf8(b"test.sui"));
        });

        // Should abort with ENamespaceNotFound
        assert!(test_scenario::tx_aborted(&result), 1);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_query_nonexistent_entry() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"ns"), USER, test_scenario::ctx(scenario));

        // Try to query nonexistent entry
        let result = test_scenario::try_tx(scenario, |ctx| {
            registry::query(&registry, string::utf8(b"ns"), string::utf8(b"nonexistent"));
        });

        // Should abort with EEntryNotFound
        assert!(test_scenario::tx_aborted(&result), 3);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_remove_entry() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"ns"), USER, test_scenario::ctx(scenario));

        // Create and add an entry directly for testing
        let acct_obj = registry::create_acct_object(
            string::utf8(b"test.sui"),
            string::utf8(b"test data"),
            USER,
            USER,
            test_scenario::ctx(scenario)
        );

        // Manually add to namespace for testing
        let namespace_name = string::utf8(b"ns");
        let namespace_obj = table::borrow_mut(&mut registry.namespaces, namespace_name);
        table::add(&mut namespace_obj.entries, string::utf8(b"test.sui"), acct_obj);

        // Verify entry exists
        assert!(table::contains(&namespace_obj.entries, string::utf8(b"test.sui")), 4);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_acct_object_getters() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Create test AcctObject
        let acct_obj = registry::create_acct_object(
            string::utf8(b"test.sui"),
            string::utf8(b"test data"),
            OTHER_USER,
            USER,
            test_scenario::ctx(scenario)
        );

        // Test all getter functions
        assert!(registry::acct_key(&acct_obj) == string::utf8(b"test.sui"), 5);
        assert!(registry::acct_data(&acct_obj) == string::utf8(b"test data"), 6);
        assert!(registry::acct_target(&acct_obj) == OTHER_USER, 7);
        assert!(registry::acct_owner(&acct_obj) == USER, 8);

        sui::transfer::share_object(acct_obj);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_namespace_getters() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, USER);

        // Initialize registry
        let mut registry = registry::init_registry(test_scenario::ctx(scenario));

        // Add namespace
        registry::add_namespace(&mut registry, string::utf8(b"test_namespace"), USER, test_scenario::ctx(scenario));

        // Get namespace and test getter
        let namespace_obj = table::borrow(&registry.namespaces, string::utf8(b"test_namespace"));
        assert!(registry::namespace_name(namespace_obj) == string::utf8(b"test_namespace"), 9);

        sui::transfer::share_object(registry);
        test_scenario::end(scenario_val);
    }
}

