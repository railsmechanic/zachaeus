# Errors

## Introduction
With Zachaeus you're able to customize the returned error message through general error codes.
If you don't like the default error messages, you can simply match on the error code and return your own messages, suitable for your use case.

```elixir
# Sample error
sample_error = %Zachaeus.Error{code: :license_expired, message: "The license has expired"}

# Match on the error code 'license_expired'
case sample_error do
  %Zachaeus.Error{code: :license_expired} ->
    {:error, "Hey dude, your license has expired!"}
  _any_other_error ->
    {:error, "Something unexpected happened"}
end
```

## Current (default) errors
The following error codes/messages are currently returned by Zachaeus:

| Code                     | Message                                                                           |
|--------------------------|-----------------------------------------------------------------------------------|
| :empty_plan              | The given plan cannot be empty                                                    |
| :invalid_license_type    | Unable to serialize license due to an invalid type                                |
| :invalid_timestamp_type  | Unable to cast timestamp to DateTime                                              |
| :empty_identifier        | The given identifier cannot be empty                                              |
| :invalid_license_format  | Unable to deserialize license string due to an invalid format                     |
| :invalid_license_type    | Unable to deserialize license due to an invalid type                              |
| :license_expired         | The license has expired                                                           |
| :invalid_license_type    | The given license is invalid                                                      |
| :license_predated        | The license is not yet valid                                                      |
| :invalid_string_type     | Unable to cast data to String                                                     |
| :invalid_identifer       | The given identifier contains a reserved character                                |
| :invalid_identifer       | The given identifier is not a String                                              |
| :invalid_plan            | The given plan contains a reserved character                                      |
| :invalid_plan            | The given plan is not a String                                                    |
| :invalid_timerange       | The given timerange is invalid                                                    |
| :invalid_timerange       | The the given timerange needs a beginning and an ending DateTime                  |
| :invalid_timestamp       | The timestamp cannot be shifted to UTC timezone                                   |
| :extraction_failed       | Unable to extract license from the HTTP Authorization request header              |
| :verification_failed     | Unable to verify the license to to an unknown error                               |
| :verification_failed     | Unable to verify the license due to an invalid type                               |
| :validation_failed       | Unable to validate license due to an unknown error                                |
| :validation_failed       | Unable to validate license due to an invalid type                                 |
| :unconfigured_secret_key | There is no secret key configured for your application                            |
| :invalid_secret_key      | The given secret key must have a size of 64 bytes                                 |
| :invalid_secret_key      | The given secret key has an invalid type                                          |
| :unconfigured_public_key | There is no public key configured for your application                            |
| :invalid_public_key      | The given public key must have a size of 32 bytes                                 |
| :invalid_public_key      | The given public key has an invalid type                                          |
| :signature_not_found     | Unable to extract the signature from the signed license                           |
| :license_tampered        | The license might be tampered as the signature does not match to the license data |
| :decoding_failed         | Unable to decode the configured public key due to an error                        |
| :public_key_unconfigured | There is no public key configured for your application                            |
| :decoding_failed         | Unable to decode the configured secret key due to an error                        |
| :secret_key_unconfigured | There is no secret key configured for your application                            |
| :empty_signed_license    | The given signed license cannot be empty                                          |
| :invalid_signed_license  | The given signed license has an invalid type                                      |
| :encoding_failed         | Unable to encode the given license data                                           |
| :decoding_failed         | Unable to decode the given license data                                           |
| :invalid_signed_license  | Unable to extract the signature due to an invalid type                            |
