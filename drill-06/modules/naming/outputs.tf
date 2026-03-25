output "prefix" {
  value = "${var.project}-${var.environment}-${random_pet.this.id}"
}