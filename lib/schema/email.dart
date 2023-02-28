import 'package:json_schema_form/json_schema_form.dart';
import 'package:json_schema2/json_schema2.dart';

final emailSchema = JsonSchema.createSchema({
  'type': 'object',
  'properties': {
    'email': {'type': 'string', 'description': 'E-Mail Address'}
  }
});