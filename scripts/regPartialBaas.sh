sudo wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x ./jq
sudo cp jq /usr/bin
resp=`curl --insecure -X PUT -H "Content-Type: application/json" -H "AUTH-TOKEN: 5eb71612eb0a778c00680cb1510fc2b26f924895" -H "Accept: application/json"  -d '{ "action_name":"GetDetails", "parameters" : { "customer" : { "customerId":"CM-ADWC1"}, "provider" : { "providerName":"Resiliency Services Param"}}}' "https://service-registry.us.gtsaasonsl.com/dev/search_instance"`
echo $resp
ServiceInstanceID=`echo "$resp" | jq -r '.SERVICE_INSTANCE_ID'`
instanceId=`curl http://169.254.169.254/latest/meta-data/instance-id`
hostname=`hostname`
cataloghost=baasDemo1
echo $hostname $cataloghost $instanceId
echo ---$ServiceInstanceID----
resp_createVM=`curl --insecure -X PUT -H "Content-Type: application/json" -H "AUTH-TOKEN: 5eb71612eb0a778c00680cb1510fc2b26f924895"  -H "Accept: application/json"  -d '{ "action_name":"CREATE", "parameters" : { "cataloghost" : "'$cataloghost'","instanceId" : "'$instanceId'","hostname" : "'$hostname'",  "region": "us-west1"} }' "https://service-registry.us.gtsaasonsl.com/dev/service_instance/$ServiceInstanceID"`
echo $resp_createVM
resp=`curl -k -H "Content-Type: application/json" -H "Accept: application/json" "https://service-registry.us.gtsaasonsl.com/dev/registry1/service_instances.json?search_by_service_resource_type=IBM%3A%3AMSP%3A%3ABaaSParamsInstance&cataloghost=$cataloghost"`
echo $resp
