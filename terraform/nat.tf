resource "aws_eip" "nat" {
  domain = "vpc"
  count  = 2

  tags = {
    Name = "openai-chatbot-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = module.vpc.public_subnets[count.index]

  tags = {
    Name = "openai-chatbot-nat-gateway-${count.index + 1}"
  }

  depends_on = [module.vpc]
}

resource "aws_route" "private_nat_gateway" {
  count                  = 2
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id

}