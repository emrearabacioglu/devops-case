describe("Web site availability", () => {
  it("Sanity listings web site", () => {
    cy.visit("http://localhost:3000");
    cy.contains("Create Record").should("exist");
  });
  
  it("Test Adding Employee listings", () => {
    cy.visit("http://localhost:3000");
    
    // NGINX 404 hatasından kaçmak için URL yerine arayüzden butona tıklıyoruz
    cy.contains("Create Record").click(); 
    
    cy.get("#name").type("Employee1");
    cy.get("#position").type("Position1");
    cy.get("#positionIntern").click({ force: true });
    cy.contains("Create person").click({ force: true });
    
    // API isteğinin gidip DB'ye yazılmasını beklemek için zorunlu mola (Race Condition Çözümü)
    cy.wait(3000); 
    
    cy.visit("http://localhost:3000");
    cy.contains("Employee1").should("exist");
  });

  after(() => {
    // İşlem bittikten sonra çöp bırakmamak için kaydı siler
    cy.contains("Delete").click({ force: true });
  });
});