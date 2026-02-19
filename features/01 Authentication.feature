Feature: Authentication
  As a Federated Catalogue API consumer
  I need to authenticate via Keycloak
  So that I can access protected endpoints

  Scenario: Keycloak is reachable
    Given CAT Keycloak is up

  Scenario: Obtain access token
    Given CAT Keycloak is up
    When fetch Keycloak token
    Then save Keycloak token

  Scenario: Access session with valid token
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up
    When request current session
    Then get http 200:Success code
