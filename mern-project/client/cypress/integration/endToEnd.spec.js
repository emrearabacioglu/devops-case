describe("Web site availability", () => {
  after(() => {
    cy.contains("Delete").click({ force: true });
  });
  it("Sanity listings web site", () => {
    cy.visit("/");
    cy.contains("Create Record").should("exist");
  });
  it("Test Adding Employee listings", () => {
    cy.visit("/create");
    cy.get("#name").type("Employee1");
    cy.get("#position").type("Position1");
    cy.get("#positionIntern").click({ force: true });
    cy.contains("Create person").click({ force: true });
    cy.visit("/");
    cy.contains("Employee1").should("exist");
  });
});
