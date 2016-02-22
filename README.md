# Examples
## Basic Let's Encrypt Workflow

Add a DNS record for dns-01 challenge:
```
Invoke-KasApiRequest $Credential "add_dns_settings" @{'zone_host'="example.com."; 'record_name'="_acme-challenge"; 'record_type'="TXT"; 'record_data'=$ACMEChallengeTokenValue; 'record_aux'=0}
```
Remove all `_acme-challenge.*` records from a domain:
```
$(Invoke-KasApiRequest $Credential "get_dns_settings" @{'zone_host'="example.com."}).Response.ReturnInfo.Where({ $_.record_type -eq "TXT" -and $_.record_name.StartsWith("_acme-challenge") }).record_id.ForEach({ Invoke-KasApiRequest $Credential "delete_dns_settings" @{'record_id'=$_} })
```
