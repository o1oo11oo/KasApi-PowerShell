function Invoke-KasApiRequest {
    [CmdletBinding()]
    [OutputType([Object])]
    Param
    (
        # Login credentials for ALL-INKL
        [Parameter(Position=0,Mandatory=$true)]
        [PSCredential]$Credential,

        # API function to call
        [Parameter(Position=1,Mandatory=$true)]
        [string]$ApiFunction,

        # parameter set, see http://kasapi.kasserver.com/dokumentation/phpdoc/packages/API%20Funktionen.html for possible values
        [Parameter(Position=2,Mandatory=$false)]
        [object]$ApiParams=@{},

        # Lifetime of the session in seconds
        [Parameter(Position=3,Mandatory=$false)]
        [int]$SessionLifeTime=1800,

        # Reset session lifetime with every request
        [Parameter(Position=4,Mandatory=$false)]
        [string]$SessionUpdateLifeTime="Y"
    )

    $KasPasswordHash = [System.BitConverter]::ToString($(New-Object System.Security.Cryptography.SHA1CryptoServiceProvider).ComputeHash($([system.Text.Encoding]::UTF8).GetBytes($Credential.GetNetworkCredential().password))).Replace("-", "")

    $KasAuthUrl = "https://kasapi.kasserver.com/soap/wsdl/KasAuth.wsdl"
    $KasApiUrl = "https://kasapi.kasserver.com/soap/wsdl/KasApi.wsdl"
    $KasAuthProxy = New-WebServiceProxy -Uri $kasauthurl
    $KasApiProxy = New-WebServiceProxy -Uri $kasapiurl
    $KasAuthProxy.Url = $KasAuthProxy.Url.Replace("http://", "https://")
    $KasAuthProxy.Url = $KasAuthProxy.Url.Replace("http://", "https://")

    $AuthRequest = New-Object PSObject
    $AuthRequest | Add-Member -Name "KasUser" -Value $Credential.UserName -MemberType NoteProperty
    $AuthRequest | Add-Member -Name "KasAuthType" -Value "sha1" -MemberType NoteProperty
    $AuthRequest | Add-Member -Name "KasPassword" -Value $KasPasswordHash -MemberType NoteProperty
    $AuthRequest | Add-Member -Name "SessionLifeTime" -Value $SessionLifeTime -MemberType NoteProperty
    $AuthRequest | Add-Member -Name "SessionUpdateLifeTime" -Value $SessionUpdateLifeTime -MemberType NoteProperty

    Try {
        $CredentialToken = $KasAuthProxy.KasAuth($(ConvertTo-Json -InputObject $AuthRequest -Compress))
    } Catch {
        Throw $_.Exception.Message
    }

    $ApiRequest = New-Object PSObject
    $ApiRequest | Add-Member -Name "KasUser" -Value $Credential.UserName -MemberType NoteProperty
    $ApiRequest | Add-Member -Name "KasAuthType" -Value "session" -MemberType NoteProperty
    $ApiRequest | Add-Member -Name "KasAuthData" -Value $CredentialToken -MemberType NoteProperty
    $ApiRequest | Add-Member -Name "KasRequestType" -Value $ApiFunction -MemberType NoteProperty
    $ApiRequest | Add-Member -Name "KasRequestParams" -Value $ApiParams -MemberType NoteProperty

    Try {
        $ApiResponse = $KasApiProxy.KasApi($(ConvertTo-Json -InputObject $ApiRequest -Compress))
    } Catch {
        Throw $_.Exception.Message
    }

    $ReturnObject = New-Object -TypeName PSObject
    $ReturnObject | Add-Member -Name $ApiResponse[1].key.FirstChild.Value -Value $(Format-KasApiResponseAsObject -Map $ApiResponse[1].value) -MemberType NoteProperty
    $ReturnObject | Add-Member -Name $ApiResponse[2].key.FirstChild.Value -Value $(Format-KasApiResponseAsObject -Map $ApiResponse[2].value) -MemberType NoteProperty
    Return $ReturnObject
}

function Format-KasApiResponseAsObject($Map) {
    $Object = New-Object -TypeName PSObject
    $Map.ChildNodes.ForEach({
        $Child = $_
        switch ($Child.value.type) {
            "xsd:string" {$Object | Add-Member -Name $Child.key.InnerText -Value $([string]$Child.value.InnerText)                  -MemberType NoteProperty; break}
            "xsd:int"    {$Object | Add-Member -Name $Child.key.InnerText -Value $([int]$Child.value.InnerText)                     -MemberType NoteProperty; break}
            "xsd:float"  {$Object | Add-Member -Name $Child.key.InnerText -Value $([float]$Child.value.InnerText)                   -MemberType NoteProperty; break}
            "ns2:Map"    {$Object | Add-Member -Name $Child.key.InnerText -Value $(Format-KasApiResponseAsObject -Map $Child.value) -MemberType NoteProperty; break}
            "SOAP-ENC:Array" {
                $Array = @()
                $Child.value.ChildNodes.ForEach({
                    $Array += $(Format-KasApiResponseAsObject -Map $_)
                })
                $Object | Add-Member -Name $Child.key.InnerText -Value $Array -MemberType NoteProperty
            }
            default {$Object | Add-Member -Name $Child.key.InnerText -Value $([bool]$Child.value.nil) -MemberType NoteProperty}
        }
    })
    Return $Object
}

Export-ModuleMember -function Invoke-KasApiRequest
