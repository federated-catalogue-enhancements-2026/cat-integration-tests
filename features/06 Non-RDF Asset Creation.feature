@domain.sd @extended @req.CAT-FR-AM-01 @cfg.default
Feature: Non-RDF Asset Creation
  As a user of the Federated Catalogue
  I want to upload assets in arbitrary formats via the /self-descriptions endpoint
  So that the catalogue can store Contract Templates, PDFs, images and other file types alongside RDF Self-Descriptions

  # The /self-descriptions endpoint is extended to accept non-RDF content types.
  # Non-RDF assets bypass RDF verification and are stored in the FileStore.
  # RDF assets continue through the existing verification + graph storage path.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up
    
  Scenario: Upload plain text file via multipart/form-data
    # A plain text contract template is uploaded as multipart/form-data.
    # The server stores it without RDF verification and returns 201 with metadata.
    When add asset from fixture "valid/non-rdf/template.txt" with content-type "text/plain"
    Then get http 201:Created code
      And response content-type is "text/plain"
      And response has file size greater than 0

  Scenario: Upload YAML config file via multipart/form-data
    # YAML files are treated as non-RDF assets.
    When add asset from fixture "valid/non-rdf/config.yaml" with content-type "application/x-yaml"
    Then get http 201:Created code
      And response content-type is "application/x-yaml"
      And response has file size greater than 0
    
  Scenario: Upload PDF binary file via multipart/form-data
    # A PDF file is uploaded as multipart/form-data with binary integrity preserved.
    When add asset from fixture "valid/non-rdf/sample.pdf" with content-type "application/pdf"
    Then get http 201:Created code
      And response content-type is "application/pdf"
      And response has file size greater than 0
    
  Scenario: Upload plain JSON without @context is stored without verification
    # A JSON file without @context is NOT JSON-LD. It is stored as a non-RDF asset
    # without going through RDF verification or graph storage.
    When add asset from fixture "valid/non-rdf/contract.json" with content-type "application/json"
    Then get http 201:Created code
      And response content-type is "application/json"
      And response has file size greater than 0
    
  Scenario: Upload file via application/octet-stream
    # Binary upload using raw body with application/octet-stream content-type.
    # The server accepts it as a non-RDF asset.
    When add asset from fixture "valid/non-rdf/sample.pdf" as raw binary
    Then get http 201:Created code
      And response has file size greater than 0