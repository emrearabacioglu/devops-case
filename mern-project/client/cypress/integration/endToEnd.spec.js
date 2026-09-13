describe("Web site availability", () => {
  after(() => {
    cy.contains("Delete").click({ force: true });
  });
  it("Sanity listings web site", () => {
    cy.visit("http://localhost:3000");
    cy.contains("Create Record").should("exist");
  });
  it("Test Adding Employee listings", () => {
    cy.intercept("POST", "**/record*").as("createRecord");

    cy.visit("http://localhost:3000/create");
    cy.get("#name").type("Employee1");
    cy.get("#position").type("Position1");
    cy.get("#positionIntern").click({ force: true });
    cy.contains("Create person").click({ force: true });

    cy.wait("@createRecord", { timeout: 15000 }).then((interception) => {
      cy.log("POST status: " + interception.response?.statusCode);
      cy.log("POST body: " + JSON.stringify(interception.response?.body));
    });

    cy.visit("http://localhost:3000");
    cy.contains("Employee1").should("exist");
  });
});