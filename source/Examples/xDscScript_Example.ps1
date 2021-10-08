Configuration LinuxTestScript {
    Import-DscResource -ModuleName PsDscResources
    Import-DscResource -ModuleName xDscScript

    Node localhost {
        xDscScript script1 {
            SetScript  = { New-Item /tmp/myfile.txt -ItemType File }
            TestScript = { Test-Path /tmp/myfile.txt }
        }
    }
}