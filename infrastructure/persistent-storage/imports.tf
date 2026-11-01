# Declarative imports adopt the six surviving volumes into this independent
# state. Because n8n is intentionally absent from existing_volume_ids, it is
# the only EBS volume that the first apply will create.
import {
  for_each = var.existing_volume_ids

  to = aws_ebs_volume.persistent[each.key]
  id = each.value
}
