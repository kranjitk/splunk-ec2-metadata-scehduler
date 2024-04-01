#!/bin/bash
# Check if Splunk is running in the background and wait until it starts
set -x
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
while ! (pgrep -x "splunkd" > /dev/null)
do
    sleep 5
done
# Check and Remove the disabled flag in the last line from the aws_metadata_tasks.conf file
last_line=$(sed -n '$p' /opt/splunk/etc/apps/Splunk_TA_aws/local/aws_metadata_tasks.conf)
if [ "$last_line" == "disabled = 1" ] 
then
    sed -i '$d' /opt/splunk/etc/apps/Splunk_TA_aws/local/aws_metadata_tasks.conf
fi    
# Wait for the aws_metadata.log file if it doesn't exist yet
while [ ! -f /opt/splunk/var/log/splunk/splunk_ta_aws_metadata.log ]
do
    sleep 5
done

# Wait for the aws_metadata input scanning all EC2 entries (10) for 2 (regions) total 20. Update this entries to your metadata input settings
# Update this value to number of entries you selected times the number of regions. Example 10 entries for 3 regions = 30  
until [ $(cat /opt/splunk/var/log/splunk/splunk_ta_aws_metadata.log  | grep "End of collecting description data" | wc -l) -ge 20 ]
do
  sleep 5
done

# Rename the aws_metadata.log file with a timestamp to avoid overwriting the file in the next run.
timestamp=$(date +%s)
$(mv /opt/splunk/var/log/splunk/splunk_ta_aws_metadata.log /opt/splunk/var/log/splunk/splunk_ta_aws_metadata_$timestamp.log)

# Send Message to SNS Topic for Completion
$(aws sns publish --topic-arn arn:aws:sns:us-east-1:XXXXXXXXXXXXXXXX:SplunkTestTopic --message "Splunk_TA_aws_metadata.log file has been successfully processed for Timestamp:$timestamp" --region $AWS_REGION > /dev/null) 

# Sleep for 5 seconds to allow SNS message to be sent and network packets to be sent from Forwarders to Splunk
sleep 5

# Check and Add the disabled flag to the aws_metadata_tasks.conf file
last_line=$(sed -n '$p' /opt/splunk/etc/apps/Splunk_TA_aws/local/aws_metadata_tasks.conf)
if [ "$last_line" != "disabled = 1" ]
then 
  sed -i '$a disabled = 1' /opt/splunk/etc/apps/Splunk_TA_aws/local/aws_metadata_tasks.conf
fi
# Shutdown the instance
shutdown -h now
set +x
