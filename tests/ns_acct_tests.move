#[test_only]
module ns_acct::ns_acct_tests {
    use ns_acct::ns_acct;
    use sui::object;
    use sui::test_scenario::{Self, Scenario};
    use sui::transfer;
    use std::string;
    use std::option;

    const ETestFailed: u64 = 0;
    const ADMIN: address = @0xAD;
    const USER: address = @0x123;

    #[test]
    fun test_acct_value_operations() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        
        // Create a test Acct object using the helper function
        let acct = ns_acct::create_test_acct(
            object::id_from_address(@0x1), 
            42, 
            test_scenario::ctx(scenario)
        );
        
        // Test value getter
        assert!(ns_acct::value(&acct) == 42, ETestFailed);
        
        // Test reg_id getter
        assert!(ns_acct::reg_id(&acct) == object::id_from_address(@0x1), ETestFailed);
        
        // In production, objects are shared and live permanently
        // For testing, we can share the object here
        transfer::public_share_object(acct);
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_acct_field_operations() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        
        // Create a test Acct object
        let mut acct = ns_acct::create_test_acct(
            object::id_from_address(@0x1), 
            0, 
            test_scenario::ctx(scenario)
        );
        
        // Test initial state
        assert!(ns_acct::extra_fields_length(&acct) == 0, ETestFailed);
        
        // Test field operations
        let test_key = string::utf8(b"test_key");
        let test_value = string::utf8(b"test_value");
        
        // Add field using helper function
        ns_acct::add_test_field(&mut acct, test_key, test_value);
        
        // Get field
        let retrieved = ns_acct::get_field(&acct, test_key);
        assert!(option::is_some(&retrieved), ETestFailed);
        assert!(*option::borrow(&retrieved) == test_value, ETestFailed);
        
        transfer::public_share_object(acct);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_acct_extra_fields_operations() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        
        // Create a test Acct object
        let mut acct = ns_acct::create_test_acct(
            object::id_from_address(@0x123), 
            42, 
            test_scenario::ctx(scenario)
        );
        
        // Test initial state
        assert!(ns_acct::extra_fields_length(&acct) == 0, ETestFailed);
        
        // Add multiple fields using helper function
        ns_acct::add_test_field(&mut acct, string::utf8(b"key1"), string::utf8(b"value1"));
        ns_acct::add_test_field(&mut acct, string::utf8(b"key2"), string::utf8(b"value2"));
        
        // Verify fields were added
        assert!(ns_acct::extra_fields_length(&acct) == 2, ETestFailed);
        
        // Test field retrieval
        let field1 = ns_acct::get_field(&acct, string::utf8(b"key1"));
        assert!(option::is_some(&field1), ETestFailed);
        assert!(*option::borrow(&field1) == string::utf8(b"value1"), ETestFailed);
        
        let field2 = ns_acct::get_field(&acct, string::utf8(b"key2"));
        assert!(option::is_some(&field2), ETestFailed);
        assert!(*option::borrow(&field2) == string::utf8(b"value2"), ETestFailed);
        
        // Test non-existent field
        let non_existent = ns_acct::get_field(&acct, string::utf8(b"non_existent"));
        assert!(option::is_none(&non_existent), ETestFailed);
        
        transfer::public_share_object(acct);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_acct_structure() {
        let mut scenario_val = test_scenario::begin(USER);
        let scenario = &mut scenario_val;
        
        // Test creating an Acct with various values
        let acct = ns_acct::create_test_acct(
            object::id_from_address(@0x999), 
            12345, 
            test_scenario::ctx(scenario)
        );
        
        // Verify all fields are set correctly
        assert!(ns_acct::value(&acct) == 12345, ETestFailed);
        assert!(ns_acct::reg_id(&acct) == object::id_from_address(@0x999), ETestFailed);
        assert!(ns_acct::extra_fields_length(&acct) == 0, ETestFailed);
        
        transfer::public_share_object(acct);
        test_scenario::end(scenario_val);
    }
}
