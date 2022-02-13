variable "role_name" {
  default = "kx-kube"
}
variable "company_vpn_ips" {
  type    = list(string)
}
variable "public_key_path" {
  description = "Public key path"
  default     = "./id_rsa.pub"
}
variable "public_key_name" {
  description = "Public key name"
  default     = "id_rsa.pub"
}
variable "filename" {
  description = "Public key name"
  # default     = "/Users/manu.john/.ssh/customers/keys/tls.pem"
}