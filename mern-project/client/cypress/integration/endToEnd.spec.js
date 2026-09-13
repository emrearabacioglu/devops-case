describe("Web site availability", () => {
  after(() => {
    cy.visit("/");
    cy.contains("a", "Record List").click();
    cy.get("body").then(($body) => {
      if ($body.find("td:contains('Employee1')").length) {
        cy.contains("td", "Employee1").parent().find("button").click({ force: true });
      }
    });
  });

  it("Sanity listings web site", () => {
    cy.visit("/");
    cy.contains("Create Record").should("exist");
  });

  it("Test Adding Employee listings", () => {
    cy.on("window:alert", (msg) => {
      throw new Error("Application raised an alert: " + msg);
    });

    cy.visit("/create");

    cy.get("#name").type("Employee1").should("have.value", "Employee1");
    cy.get("#position").type("Position1").should("have.value", "Position1");
    cy.get("#positionIntern").check({ force: true }).should("be.checked");

    cy.get('input[type="submit"][value="Create person"]').click();

    // API seviyesinde dogrulama: kayit veritabanina yazildi mi
    cy.request("/record/").its("body").then((records) => {
      expect(records.map((r) => r.name)).to.include("Employee1");
    });

    // Record list "/" altinda degil, navbar'daki Record List sayfasinda
    cy.contains("a", "Record List").click();
    cy.contains("td", "Employee1", { timeout: 20000 }).should("exist");
  });
});
