$Domain  = "X.com"
$Suffix  = "@$Domain"
$CsvPath = ".\X-Recipients.csv"

$Results = Get-Recipient -ResultSize Unlimited |
    Where-Object {
        $_.EmailAddresses | Where-Object {
            # Remove the SMTP:/smtp: proxy prefix before testing the domain
            ($_.ToString() -replace '^(?i)smtp:', '').EndsWith(
                $Suffix,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
    } |
    Select-Object `
        DisplayName,
        PrimarySmtpAddress,
        RecipientType,
        RecipientTypeDetails,
        ExternalEmailAddress,
        @{
            Name = "MatchingAddresses"
            Expression = {
                (
                    $_.EmailAddresses |
                    ForEach-Object {
                        $_.ToString() -replace '^(?i)smtp:', ''
                    } |
                    Where-Object {
                        $_.EndsWith(
                            $Suffix,
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    }
                ) -join ";"
            }
        }

$Results |
    Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

$Results |
    Format-Table DisplayName, PrimarySmtpAddress,
        RecipientTypeDetails, MatchingAddresses -AutoSize

Write-Host "`nFound $($Results.Count) recipient(s)."
Write-Host "Exported to: $CsvPath"
