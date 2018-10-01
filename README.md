Run with a command like this:

terraform apply -var 'key_name={your_aws_key_name}' \
   -var 'public_key_path={location_of_your_key_in_your_local_machine}'

For RDS user
Pass the password variable through your ENV variable.
