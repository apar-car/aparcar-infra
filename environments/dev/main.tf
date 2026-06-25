module "vpc" {
    source = "../../modules/vpc"

    environment          = "dev"
    vpc_cidr             = "10.16.0.0/16"
    private_subnet_cidrs = ["10.16.1.0/24", "10.16.2.0/24"]
    availability_zones   = ["eu-west-1a", "eu-west-1b"]
    project              = "aparcar"
    enable_nat_gateway   = false 
}