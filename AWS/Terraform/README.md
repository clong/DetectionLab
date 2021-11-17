# DetectionLab Terraform

## Cost
```
terraform state pull |  curl -s -X POST -H "Content-Type: application/json" -d @- https://cost.modules.tf/
{"hourly": 0.26, "monthly": 186.62}
```
---

### Method 1 - Pre-built AMIs
https://www.detectionlab.network/deployment/aws/

### Method 2 - Building the VMs locally and exporting them to AWS as AMIs
#### Estimated time to build: 3-4 hours
https://www.detectionlab.network/customization/buildami/