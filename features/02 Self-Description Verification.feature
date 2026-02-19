Feature: Self-Description Verification
  As a Federated Catalogue API consumer
  I want to verify a Self-Description
  So that I can check its validity before submitting it

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  Scenario: Verify a valid Self-Description
    When verify self-description from fixture "valid/gaiax-participant.vp.jsonld"
    Then get http 200:Success code

  Scenario: Verify an invalid Self-Description returns error
    When verify self-description
      """
      { "invalid": "payload" }
      """
    Then get http 422:Unprocessable Entity code
