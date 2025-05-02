# tsvikli
Cloud-Based Remote Desktop SaaS tool

## Usage

### Prerequisites

1. Terraform
2. Configured AWS CLI
3. Docker
4. Python/pip
5. NPM

### Configuration

1. To deploy Tsvikli infrastructure, you need to set up Hosted Zone in AWS Route 53.
2. DNS nameservers from Hosted Zone must be specified in domain registrar domain setup.
3. Zone id, AWS main region, frontend bucket name, domain name must be specified in .tfvars file or terraform/variables.tf. [See file](terraform/variables.tf) for variables names.
4. [terraform/bootstrap/variables.tf](terraform/bootstrap/variables.tf) state bucket name and region must be explicitly specified too.
5. Region and state bucket must be updated in [terraform/backend.tf](terraform/backend.tf)
6. Network configuration can be changed in [terraform/network/variables.tf](terraform/network/variables.tf)

#### Config file

Connections and users can be specified in [config.yaml](config.yaml). Follow templates from the file.

### Deployment

1. Deploy bootstrap infrastructure:  
```bash
cd terraform/bootstrap/
terraform init
terraform apply
cd ../../
```

2. Upload docker image
```bash
cd terraform/resources/docker/
export DOCKER_DEFAULT_PLATFORM=linux/amd64
./push_image.sh --region eu-west-1 --repo tsvikli/guacamole
cd ../../../
```

3. Build frontend:
```bash
cd frontend/
npm install
npm run build
cd ../
```

4. Install lambda pip packages:
```bash
pip install pymysql -t terraform/resources/db_init/
pip install pymysql pyyaml -t terraform/resources/db_update/
```

5. Deploy infrastructure:
```bash
cd terraform/
terraform init
terraform apply
```
After deployment, resource shall be available on specified domain.  
To change configuration, make changes to `config.yaml` and deploy infrastructure (step 5) again.  
Changes should be applied.

### Infrastructure destroy:

```bash
cd terraform/
terraform destroy
cd bootstrap/
terraform destroy
```
Also, you may delete Hosted Zone if you need.
