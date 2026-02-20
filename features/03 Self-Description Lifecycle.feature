@domain.sd @baseline
Feature: Self-Description Lifecycle
  As a Federated Catalogue API consumer
  I want to manage Self-Descriptions
  So that I can create, read, and revoke them

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  @smoke
  Scenario: List Self-Descriptions
    When request list of self-descriptions
    Then get http 200:Success code

  @smoke @domain.participant
  Scenario: List Participants
    When request list of participants
    Then get http 200:Success code

  @smoke @domain.schema
  Scenario: List Schemas
    When request list of schemas
    Then get http 200:Success code