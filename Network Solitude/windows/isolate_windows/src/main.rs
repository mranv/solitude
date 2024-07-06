use windows::{
    core::Result,
    Win32::Foundation::*,
    Win32::NetworkManagement::WindowsFilteringPlatform::*,
    Win32::Networking::WinSock::*,
    Win32::Security::*,
    Win32::System::Threading::*,
    Win32::System::SystemServices::RPC_C_AUTHN_DEFAULT,
};

fn main() -> Result<()> {
    let ip = "192.168.1.100"; // Replace with your IP
    let port1 = 1515;
    let port2 = 8080; // Replace with your port

    unsafe {
        let mut session_handle: HANDLE = HANDLE::default();
        let session_name = "My Firewall Session";
        let session_desc = "Session to isolate Windows";

        let session = FWPM_SESSION0 {
            sessionKey: Default::default(),
            displayData: FWPM_DISPLAY_DATA0 {
                name: PWSTR(session_name.encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
                description: PWSTR(session_desc.encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
            },
            ..Default::default()
        };

        let result = FwpmEngineOpen0(
            None,
            RPC_C_AUTHN_DEFAULT,
            None,
            &session,
            &mut session_handle,
        );
        if result != ERROR_SUCCESS.0 as i32 {
            println!("Failed to open WFP engine: {}", result);
            return Err(windows::core::Error::from_win32());
        }

        // Clear existing rules
        FwpmEnginePurge0(session_handle)?;

        // Add rules to block all incoming and outgoing traffic
        add_block_all_rules(session_handle)?;

        // Add rules to allow traffic for specific IP and ports
        add_allow_rule(session_handle, ip, port1)?;
        add_allow_rule(session_handle, ip, port2)?;

        // Add rules to allow loopback traffic
        add_allow_loopback_rules(session_handle)?;

        // Close WFP session
        FwpmEngineClose0(session_handle)?;
    }

    Ok(())
}

unsafe fn add_block_all_rules(engine_handle: HANDLE) -> Result<()> {
    let conditions = &mut [];
    let filter = FWPM_FILTER0 {
        filterKey: GUID::zeroed(),
        displayData: FWPM_DISPLAY_DATA0 {
            name: PWSTR("Block All Traffic".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
            description: PWSTR("Block all incoming and outgoing traffic".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
        },
        layerKey: FWPM_LAYER_INBOUND_TRANSPORT_V4,
        action: FWPM_ACTION0 {
            r#type: FWP_ACTION_BLOCK,
            ..Default::default()
        },
        numFilterConditions: 0,
        filterCondition: conditions.as_mut_ptr(),
        subLayerKey: GUID::zeroed(),
        weight: FWP_VALUE0 {
            r#type: FWP_EMPTY,
            ..Default::default()
        },
        ..Default::default()
    };

    FwpmFilterAdd0(engine_handle, &filter, None, std::ptr::null_mut())?;
    Ok(())
}

unsafe fn add_allow_rule(engine_handle: HANDLE, ip: &str, port: u16) -> Result<()> {
    let ip_addr: u32 = ip.parse::<std::net::Ipv4Addr>()?.into();
    let conditions = &mut [
        FWPM_FILTER_CONDITION0 {
            fieldKey: FWPM_CONDITION_IP_REMOTE_ADDRESS,
            matchType: FWP_MATCH_EQUAL,
            conditionValue: FWP_CONDITION_VALUE0 {
                r#type: FWP_UINT32,
                value: FWP_VALUE0 {
                    uint32: ip_addr,
                    ..Default::default()
                },
            },
        },
        FWPM_FILTER_CONDITION0 {
            fieldKey: FWPM_CONDITION_IP_REMOTE_PORT,
            matchType: FWP_MATCH_EQUAL,
            conditionValue: FWP_CONDITION_VALUE0 {
                r#type: FWP_UINT16,
                value: FWP_VALUE0 {
                    uint16: port,
                    ..Default::default()
                },
            },
        },
    ];

    let filter = FWPM_FILTER0 {
        filterKey: GUID::zeroed(),
        displayData: FWPM_DISPLAY_DATA0 {
            name: PWSTR("Allow Specific Traffic".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
            description: PWSTR("Allow traffic for specific IP and port".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
        },
        layerKey: FWPM_LAYER_INBOUND_TRANSPORT_V4,
        action: FWPM_ACTION0 {
            r#type: FWP_ACTION_PERMIT,
            ..Default::default()
        },
        numFilterConditions: conditions.len() as u32,
        filterCondition: conditions.as_mut_ptr(),
        subLayerKey: GUID::zeroed(),
        weight: FWP_VALUE0 {
            r#type: FWP_EMPTY,
            ..Default::default()
        },
        ..Default::default()
    };

    FwpmFilterAdd0(engine_handle, &filter, None, std::ptr::null_mut())?;
    Ok(())
}

unsafe fn add_allow_loopback_rules(engine_handle: HANDLE) -> Result<()> {
    let conditions = &mut [
        FWPM_FILTER_CONDITION0 {
            fieldKey: FWPM_CONDITION_IP_LOCAL_INTERFACE,
            matchType: FWP_MATCH_EQUAL,
            conditionValue: FWP_CONDITION_VALUE0 {
                r#type: FWP_UINT32,
                value: FWP_VALUE0 {
                    uint32: 1, // Loopback interface index
                    ..Default::default()
                },
            },
        },
    ];

    let filter = FWPM_FILTER0 {
        filterKey: GUID::zeroed(),
        displayData: FWPM_DISPLAY_DATA0 {
            name: PWSTR("Allow Loopback Traffic".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
            description: PWSTR("Allow traffic for loopback interface".encode_utf16().collect::<Vec<u16>>().as_mut_ptr()),
        },
        layerKey: FWPM_LAYER_INBOUND_TRANSPORT_V4,
        action: FWPM_ACTION0 {
            r#type: FWP_ACTION_PERMIT,
            ..Default::default()
        },
        numFilterConditions: conditions.len() as u32,
        filterCondition: conditions.as_mut_ptr(),
        subLayerKey: GUID::zeroed(),
        weight: FWP_VALUE0 {
            r#type: FWP_EMPTY,
            ..Default::default()
        },
        ..Default::default()
    };

    FwpmFilterAdd0(engine_handle, &filter, None, std::ptr::null_mut())?;
    Ok(())
}
