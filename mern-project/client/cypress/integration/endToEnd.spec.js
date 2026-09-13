describe("Web site availability", () => {
  after(() => {
    cy.visit("/");
    cy.contains("td", "Employee1").parent().find("button").click({ force: true });
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
    cy.contains("Employee1", { timeout: 15000 }).should("exist");
  });
});
