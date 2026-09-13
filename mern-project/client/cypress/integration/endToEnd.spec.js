describe("Web site availability", () => {
  after(() => {
    cy.contains("Delete").click({ force: true });
  });
  it("Sanity listings web site", () => {
    cy.visit("http://localhost:3000");
    cy.contains("Create Record").should("exist");
  });
  it("Test Adding Employee listings", () => {
    cy.server();
    cy.route("POST", "**/record*").as("createRecord");

    cy.visit("http://localhost:3000/create");
    cy.get("#name").type("Employee1");
    cy.get("#position").type("Position1");
    cy.get("#positionIntern").click({ force: true });
    cy.contains("Create person").click({ force: true });

    cy.wait("@createRecord", { timeout: 15000 }).then((xhr) => {
      cy.log("POST status: " + xhr.status);
      cy.log("POST body: " + JSON.stringify(xhr.responseBody));
    });

    cy.visit("http://localhost:3000");
    cy.contains("Employee1").should("exist");
  });
});