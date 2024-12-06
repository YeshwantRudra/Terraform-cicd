 # write terraform script to deploy static application with auto scaling and load balancer whep cpu usgae is above 50 and scale down server when cpu is blow 50(cloud watch,alaram)
 # hello
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "yt-vpc"
  }
}

//2. create subnet
variable "vpc_availability_zones" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["ap-south-1a", "ap-south-1b"]
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id
  count             = length(var.vpc_availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.custom_vpc.cidr_block, 8, count.index + 1)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "YT Public subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id
  count             = length(var.vpc_availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.custom_vpc.cidr_block, 8, count.index + 3)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "YT Private subnet ${count.index + 1}"
  }
}

//3. Internet Gateway
resource "aws_internet_gateway" "igw_vpc" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "YT-Internet Gateway"
  }
}

//4. Route table for public subnet
resource "aws_route_table" "yt_route_table_public_subnet" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_vpc.id
  }
  tags = {
    Name = "Public subnet Route Table"
  }
}

//5. Route table association with public subnet
resource "aws_route_table_association" "public_subnet_association" {
  route_table_id = aws_route_table.yt_route_table_public_subnet.id
  count          = length(var.vpc_availability_zones)
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
}

//6. Elastic IP
resource "aws_eip" "eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw_vpc]
}


//7. NAT Gateway
resource "aws_nat_gateway" "yt-nat-gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = element(aws_subnet.public_subnet[*].id, 0)
  depends_on    = [aws_internet_gateway.igw_vpc]
  tags = {
    Name = "YT-Nat Gateway"
  }
}

//8. Route table for Private subnet
resource "aws_route_table" "yt_route_table_private_subnet" {
  depends_on = [aws_nat_gateway.yt-nat-gateway]
  vpc_id     = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.yt-nat-gateway.id
  }
  tags = {
    Name = "Private subnet Route Table"
  }
}

//9. Route table association with private subnet
resource "aws_route_table_association" "private_subnet_association" {
  route_table_id = aws_route_table.yt_route_table_private_subnet.id
  count          = length(var.vpc_availability_zones)
  subnet_id      = element(aws_subnet.private_subnet[*].id, count.index)
}


#1. Security Group for ALB (Internet -> ALB)
resource "aws_security_group" "alb_sg" {
  name        = "yt-alb-sg"
  description = "Security Group for Application Load Balancer"

  vpc_id = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "yt-alb-sg"
  }
}

# Security Group for EC2 Instances (ALB -> EC2)
resource "aws_security_group" "ec2_sg" {
  name        = "yt-ec2-sg"
  description = "Security Group for Web Server Instances"

  vpc_id = aws_vpc.custom_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "yt-ec2-sg"
  }
}

#2. Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "yt-app-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnet[*].id
  depends_on         = [aws_internet_gateway.igw_vpc]
}

# Target Group for ALB
resource "aws_lb_target_group" "alb_ec2_tg" {
  name     = "yt-web-server-tg-14-96"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id
  tags = {
    Name = "yt-alb_ec2_tg-14-96"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ec2_tg.arn
  }
  tags = {
    Name = "yt-alb-listener-14-96"
  }
}

#3. Launch Template for EC2 Instances
resource "aws_launch_template" "ec2_launch_template" {
  name = "yt-web-server-14-96"

  image_id      = "ami-0dee22c13ea7a9a67" //Copy the ami id from aws console
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "yt-ec2-web-server-14-96"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ec2_asg" {
  name                = "yt-web-server-asg-14-96"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 3
  target_group_arns   = [aws_lb_target_group.alb_ec2_tg.arn]
  vpc_zone_identifier = aws_subnet.private_subnet[*].id

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}


# Step 4: CloudWatch Alarm for CPU Usage > 50% (Scale-Up)
resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "cpu-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Trigger scale-up when CPU usage is above 50%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

# Step 5: CloudWatch Alarm for CPU Usage < 50% (Scale-Down)
resource "aws_cloudwatch_metric_alarm" "cpu_low_alarm" {
  alarm_name          = "cpu-usage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Trigger scale-down when CPU usage is below 50%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  scaling_adjustment      = 1  # Number of instances to add
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 300  # 5 minutes cooldown
  autoscaling_group_name   = aws_autoscaling_group.ec2_asg.name  # Correct argument

  policy_type             = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  scaling_adjustment      = -1  # Number of instances to remove
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 300  # 5 minutes cooldown
  autoscaling_group_name   = aws_autoscaling_group.ec2_asg.name  # Correct argument

  policy_type             = "SimpleScaling"
}


output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
