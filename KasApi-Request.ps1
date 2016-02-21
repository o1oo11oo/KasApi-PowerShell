$ApiFunction = "get_domains"
$ApiParams = New-Object PSObject

$Config = ConvertFrom-Json -InputObject $( Get-Content .\config.json -Raw )
$KasPasswordHash = [System.BitConverter]::ToString($(New-Object System.Security.Cryptography.SHA1CryptoServiceProvider).ComputeHash($([system.Text.Encoding]::UTF8).GetBytes($Config.KasPassword))).Replace("-", "")

function KasApiResponse-ToObject($Map) {
    $Object = New-Object -TypeName PSObject
    $Map.ChildNodes.ForEach({
        $Child = $_
        switch ($Child.value.type) {
            "xsd:string" {$Object | Add-Member -Name $Child.key.FirstChild.Value -Value $([string]$Child.value.InnerText)            -MemberType NoteProperty; break}
            "xsd:int"    {$Object | Add-Member -Name $Child.key.FirstChild.Value -Value $([int]$Child.value.InnerText)               -MemberType NoteProperty; break}
            "xsd:float"  {$Object | Add-Member -Name $Child.key.FirstChild.Value -Value $([float]$Child.value.InnerText)             -MemberType NoteProperty; break}
            "ns2:Map"    {$Object | Add-Member -Name $Child.key.FirstChild.Value -Value $(KasApiResponse-ToObject -Map $Child.value) -MemberType NoteProperty; break}
            "SOAP-ENC:Array" {
                $Array = @()
                $Child.value.ChildNodes.ForEach({
                    $Array += $(KasApiResponse-ToObject -Map $_)
                })
                $Object | Add-Member -Name $Child.key.FirstChild.Value -Value $Array -MemberType NoteProperty
            }
            default {$Object | Add-Member -Name $Child.key.FirstChild.Value -Value $([bool]$Child.value.nil) -MemberType NoteProperty}
        }
    })
    Return $Object
}

$KasAuthUrl = "https://kasapi.kasserver.com/soap/wsdl/KasAuth.wsdl"
$KasApiUrl = "https://kasapi.kasserver.com/soap/wsdl/KasApi.wsdl"
$KasAuthProxy = New-WebServiceProxy -Uri $kasauthurl
$KasApiProxy = New-WebServiceProxy -Uri $kasapiurl
$KasAuthProxy.Url = $KasAuthProxy.Url.Replace("http://", "https://")
$KasAuthProxy.Url = $KasAuthProxy.Url.Replace("http://", "https://")

$AuthRequest = New-Object PSObject
$AuthRequest | Add-Member -Name "KasUser" -Value $Config.KasUser -MemberType NoteProperty
$AuthRequest | Add-Member -Name "KasAuthType" -Value "sha1" -MemberType NoteProperty
$AuthRequest | Add-Member -Name "KasPassword" -Value $KasPasswordHash -MemberType NoteProperty
$AuthRequest | Add-Member -Name "SessionLifeTime" -Value $Config.SessionLifeTime -MemberType NoteProperty
$AuthRequest | Add-Member -Name "SessionUpdateLifeTime" -Value $Config.SessionUpdateLifeTime -MemberType NoteProperty

Try {
    $CredentialToken = $KasAuthProxy.KasAuth($(ConvertTo-Json -InputObject $AuthRequest -Compress))
} Catch {
    Write-Output $_.Exception.Message
    Break
}

$ApiRequest = New-Object PSObject
$ApiRequest | Add-Member -Name "KasUser" -Value $Config.KasUser -MemberType NoteProperty
$ApiRequest | Add-Member -Name "KasAuthType" -Value "session" -MemberType NoteProperty
$ApiRequest | Add-Member -Name "KasAuthData" -Value $CredentialToken -MemberType NoteProperty
$ApiRequest | Add-Member -Name "KasRequestType" -Value $ApiFunction -MemberType NoteProperty
$ApiRequest | Add-Member -Name "KasRequestParams" -Value $ApiParams -MemberType NoteProperty

Try {
    $ApiResponse = $KasApiProxy.KasApi($(ConvertTo-Json -InputObject $ApiRequest -Compress))
} Catch {
    Write-Output $_.Exception.Message
    Break
}

$ReturnObject = New-Object -TypeName PSObject
$ReturnObject | Add-Member -Name $ApiResponse[1].key.FirstChild.Value -Value $(KasApiResponse-ToObject -Map $ApiResponse[1].value) -MemberType NoteProperty
$ReturnObject | Add-Member -Name $ApiResponse[2].key.FirstChild.Value -Value $(KasApiResponse-ToObject -Map $ApiResponse[2].value) -MemberType NoteProperty
Return $ReturnObject
