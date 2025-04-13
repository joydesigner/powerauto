function Send-HealthAlert {
    <#
    .SYNOPSIS
        Sends health alert notifications through multiple channels.
    
    .DESCRIPTION
        Handles sending alerts via email, Microsoft Teams, Slack, or SMS with customizable severity levels.
        Can be used standalone or integrated with monitoring functions.

    .PARAMETER Message
        The alert message content.

    .PARAMETER Severity
        The severity level of the alert (Info, Warning, Critical).

    .PARAMETER ComputerName
        The affected server or device name.

    .PARAMETER AlertType
        The category of alert (Disk, CPU, Memory, Service, Other).

    .PARAMETER NotificationMethod
        How the alert should be sent (Email, Teams, Slack, All).

    .PARAMETER EmailRecipients
        Email addresses to receive the alert (comma-separated).

    .PARAMETER TeamsWebhookUrl
        Microsoft Teams incoming webhook URL.

    .PARAMETER SlackWebhookUrl
        Slack incoming webhook URL.

    .PARAMETER SmsRecipients
        Phone numbers for SMS alerts (requires SMS gateway setup).

    .EXAMPLE
        # Basic email alert
        Send-HealthAlert -Message "Disk space below threshold" -Severity Warning -ComputerName "SRV01" -AlertType Disk

    .EXAMPLE
        # Critical alert to multiple channels
        Send-HealthAlert -Message "CPU at 100% for 15 minutes" -Severity Critical -ComputerName "SRV-DB01" -AlertType CPU `
                        -NotificationMethod All -EmailRecipients "admin@company.com","team@company.com" `
                        -TeamsWebhookUrl "https://outlook.office.com/webhook/..." -SlackWebhookUrl "https://hooks.slack.com/..."

    .EXAMPLE
        # Integrated with monitoring
        Get-Service -ComputerName "SRV-WEB01" -Name "W3SVC" | Where-Object { $_.Status -ne "Running" } | 
            ForEach-Object {
                Send-HealthAlert -Message "Web service stopped on $($_.MachineName)" -Severity Critical -AlertType Service
            }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Info", "Warning", "Critical")]
        [string]$Severity = "Warning",

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ComputerName = [System.Environment]::MachineName,

        [Parameter()]
        [ValidateSet("Disk", "CPU", "Memory", "Service", "Other")]
        [string]$AlertType = "Other",

        [Parameter()]
        [ValidateSet("Email", "Teams", "Slack", "SMS", "All")]
        [string]$NotificationMethod = "Email",

        [Parameter()]
        [string[]]$EmailRecipients = @("admin@company.com"),

        [Parameter()]
        [string]$TeamsWebhookUrl,

        [Parameter()]
        [string]$SlackWebhookUrl,

        [Parameter()]
        [string[]]$SmsRecipients,

        [Parameter()]
        [string]$SmtpServer = "smtp.company.com",

        [Parameter()]
        [string]$FromAddress = "alerts@company.com"
    )

    begin {
        # Severity color mapping
        $severityColors = @{
            Info    = "Green"
            Warning = "Yellow"
            Critical = "Red"
        }

        # Alert type icons
        $alertIcons = @{
            Disk    = "💾"
            CPU     = "🚀"
            Memory  = "🧠"
            Service = "⚙️"
            Other   = "⚠️"
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    process {
        try {
            # Create rich message payload
            $fullMessage = @"
$($alertIcons[$AlertType]) [$Severity] $AlertType Alert on $ComputerName
Timestamp: $timestamp
Message: $Message
"@

            # Email Notification
            if ($NotificationMethod -in ("Email", "All")) {
                try {
                    $mailParams = @{
                        To         = $EmailRecipients
                        From       = $FromAddress
                        Subject    = "[$Severity] $AlertType Alert - $ComputerName"
                        Body       = $fullMessage
                        SmtpServer = $SmtpServer
                        Priority   = if ($Severity -eq "Critical") { "High" } else { "Normal" }
                    }

                    Send-MailMessage @mailParams -ErrorAction Stop
                    Write-Verbose "Email alert sent to $($EmailRecipients -join ', ')"
                }
                catch {
                    Write-Error "Failed to send email alert: $_"
                }
            }

            # Microsoft Teams Notification
            if ($TeamsWebhookUrl -and $NotificationMethod -in ("Teams", "All")) {
                try {
                    $teamsPayload = @{
                        "@type"      = "MessageCard"
                        "@context"   = "http://schema.org/extensions"
                        "themeColor" = $severityColors[$Severity]
                        "title"      = "[$Severity] $AlertType Alert"
                        "text"       = $fullMessage
                        "sections"   = @(
                            @{
                                "facts" = @(
                                    @{
                                        "name"  = "Computer:"
                                        "value" = $ComputerName
                                    },
                                    @{
                                        "name"  = "Timestamp:"
                                        "value" = $timestamp
                                    },
                                    @{
                                        "name"  = "Details:"
                                        "value" = $Message
                                    }
                                )
                            }
                        )
                    }

                    Invoke-RestMethod -Uri $TeamsWebhookUrl -Method Post -Body ($teamsPayload | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
                    Write-Verbose "Teams notification sent"
                }
                catch {
                    Write-Error "Failed to send Teams alert: $_"
                }
            }

            # Slack Notification
            if ($SlackWebhookUrl -and $NotificationMethod -in ("Slack", "All")) {
                try {
                    $slackPayload = @{
                        text    = "*[$Severity] $AlertType Alert*"
                        blocks  = @(
                            @{
                                type = "section"
                                text = @{
                                    type = "mrkdwn"
                                    text = "*$($alertIcons[$AlertType]) [$Severity] $AlertType Alert on $ComputerName*"
                                }
                            },
                            @{
                                type = "section"
                                fields = @(
                                    @{
                                        type = "mrkdwn"
                                        text = "*Computer:*\n$ComputerName"
                                    },
                                    @{
                                        type = "mrkdwn"
                                        text = "*Timestamp:*\n$timestamp"
                                    },
                                    @{
                                        type = "mrkdwn"
                                        text = "*Details:*\n$Message"
                                    }
                                )
                            }
                        )
                    }

                    Invoke-RestMethod -Uri $SlackWebhookUrl -Method Post -Body ($slackPayload | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
                    Write-Verbose "Slack notification sent"
                }
                catch {
                    Write-Error "Failed to send Slack alert: $_"
                }
            }

            # SMS Notification (would require SMS gateway integration)
            if ($SmsRecipients -and $NotificationMethod -in ("SMS", "All")) {
                try {
                    # This is a placeholder - actual implementation would depend on your SMS gateway
                    Write-Warning "SMS alerting would be sent to $($SmsRecipients -join ', ')"
                    Write-Verbose "SMS content: [$Severity] $AlertType alert on $ComputerName - $Message"
                    # Actual implementation might use something like:
                    # Send-SmsViaGateway -Numbers $SmsRecipients -Message $shortMessage
                }
                catch {
                    Write-Error "Failed to send SMS alert: $_"
                }
            }
        }
        catch {
            Write-Error "Failed to process alert: $_"
        }
    }

    end {
        Write-Verbose "Alert processing completed"
    }
}