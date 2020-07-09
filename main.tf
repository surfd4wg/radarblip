#main.tf

provider "aws" {
    region = "us-east-2"
    access_key = "XXXXXXXXXXXXX"
    secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXX"
}


resource "aws_vpc" "main" {
    cidr_block = "10.1.0.0/16"
    tags ={
        name = "Main VPC"
    }
}

resource "aws_internet_gateway" "main" { 
    vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "main" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.1.1.0/24"
    availability_zone= "us-east-2a"
}

resource "aws_route_table" "default"{
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
}

resource "aws_route_table_association" "main" {
    subnet_id = aws_subnet.main.id
    route_table_id = aws_route_table.default.id
}

resource "aws_network_acl" "allowall" {
    vpc_id = aws_vpc.main.id 

    #Allow All Out
    egress {
        protocol = "-1"
        rule_no = 100
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0    
    }
    #Allow All In
    ingress {
        protocol = "-1"
        rule_no = 200
        action = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port = 0
    }
}

resource "aws_security_group" "allowall" {
    name = "Main VPC Allow All"
    description = "Allows All traffic"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 1880
        to_port = 1880
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 18800
        to_port = 18800
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#### BROKEN
resource "aws_eip" "webserver" {
    instance = aws_instance.webserver.id 
    vpc = true  
    depends_on = [aws_internet_gateway.main]
}

resource "aws_key_pair" "default" {
    key_name = "ubuntu"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcvwIgTaxphl90fv1e5MKxBNCKuCt9u97g6iqXOZ3T2CcJXAvz29i4QL25E55Wad37jbgMTvCJAyTAVgOKZ9TyYAoNMjJNkKlwH9xuAWCV9HcN74ACSeafQ8+ex6xKWohF725Ega3StAehHtucQwCF8Ae+rKkqlWHDylwLIElCxvKR/NhRcWC6xP42h1NkbYFn8iLtL85KXbobhfgnM+U9sA79vKLQl+6TOaqGZOKgqH1QHSEpW28Y8g0OsWI/TPIn3pGf2QfIShRIZUrSjgzEDbsLZHnIDz4s7UHqsmVA9GXh22tzHT6Cu6uzPwDTf3Ea7BjZ1BJBEqAmNbpNWQamLOc9aJ3JJgz8Lm/wPnAc9CoTJICZSg16aBkgFWohyh6mfj3TiljZ8bulDp4Wl9C5Scu4y53Pti51fhCX1mKnmqVNKOjxlbIS6h/b6PYXJRR3zpXjeKlzn2xuHr5cAfEg70Vtu3YleZo3Xti96ahSRvsCNkyhlZ2cvi+gOOf3bxU= ubuntu"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "webserver" {
    ami =  "${data.aws_ami.ubuntu.id}"
    availability_zone = "us-east-2a"
    instance_type = "t2.micro"
    key_name = aws_key_pair.default.key_name
    vpc_security_group_ids = [aws_security_group.allowall.id]
    subnet_id = aws_subnet.main.id
    associate_public_ip_address = true
 
 
   connection {
    # The default username for our AMI
    user = "ubuntu"
    type = "ssh"
    private_key = "${file("./.ssh/ubuntu")}"
    host = self.public_ip
    # The connection will use the local SSH agent for authentication.
   }

  provisioner "remote-exec" {
    inline = [
      #Update:
      #touch indicator to know if this works:
      # install nginx
      "sudo apt-get -y update",
      "sudo amazon-linux-extras enable nginx1.12",
      "sudo apt-get -y install nginx",
      "sudo systemctl start nginx",
      # install nodejs
      "sudo curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "sudo apt-get install -y npm",
      # installred
      "sudo npm install -g --unsafe-perm node-red node-red-admin",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/.node-red/*",
      # make node-red startup on reboot
      "sudo npm install node-l -g --unsafe-perm pm2",

      "pm2 start `which node-red` -- -v",
      "pm2 save",
      "pm2 startup",
      "pm2 stop node-red",
    # clone the radarblip node-red flows
      "touch /home/ubuntu/.node-red",
      "wget https://raw.githubusercontent.com/surfd4wg/radarblip/master/flows.json -O /home/ubuntu/.node-red/flows.json",
      "wget https://raw.githubusercontent.com/surfd4wg/radarblip/master/settings.js -O /home/ubuntu/.node-red/settings.js",
      "sudo ufw allow 1880",
      "sudo ufw allow 18800",
      "sudo apt-get install -y p7zip-full",
      "sudo apt-get install -y unzip",
       # make directory and copy of RSS Generator
      "mkdir /home/ubuntu/ga-gen",
      "mkdir /home/ubuntu/.node-red/certs",
      "wget https://raw.githubusercontent.com/surfd4wg/radarblip/master/privkey.pem -O /home/ubuntu/.node-red/certs/privkey.pem",
      "wget https://raw.githubusercontent.com/surfd4wg/radarblip/master/fullchain.pem -O /home/ubuntu/.node-red/certs/fullchain.pem",
      "wget https://raw.githubusercontent.com/surfd4wg/radarblip/master/package.json -O /home/ubuntu/.node-red/package.json",
      #get the node_modules folder for node_red
      "wget https://github.com/surfd4wg/radarblip/raw/master/node_modules.zip.001 -O /home/ubuntu/.node-red/node_modules.zip.001",
      "wget https://github.com/surfd4wg/radarblip/raw/master/node_modules.zip.002 -O /home/ubuntu/.node-red/node_modules.zip.002",
      "wget https://github.com/surfd4wg/radarblip/raw/master/node_modules.zip.003 -O /home/ubuntu/.node-red/node_modules.zip.003",
      "wget https://github.com/surfd4wg/radarblip/raw/master/node_modules.zip.004 -O /home/ubuntu/.node-red/node_modules.zip.004",
      "cd /home/ubuntu/.node-red",
      "7za x node_modules.zip.001",
      #Remove the zip stuff
      "rm node_modules.zip.00?",

      #get the package-lock.json
      "wget https://github.com/surfd4wg/radarblip/raw/master/package-lock.json -O /home/ubuntu/.node-red/package-lock.json",
        

      "wget https://github.com/surfd4wg/radarblip/raw/master/ga-gen.zip -O /home/ubuntu/ga-gen/ga-gen.zip",
      "unzip /home/ubuntu/ga-gen/ga-gen.zip -d /home/ubuntu/",  
      "rm /home/ubuntu/ga-gen/ga-gen.zip",
      #"sudo cp /home/ubuntu/.node-red/settings.js /home/ubuntu/.node-red/settings.js.bak",
      #"sudo sed -i 's/1880/18800/g' /home/ubuntu/.node-red/settings.js",
      #"sudo node-red-admin target http://localhost:18800",
      "pm2 start `which node-red` -- -v"

    
    ]
  }


}

output "public_ip" {
    value = aws_eip.webserver.public_ip
}
