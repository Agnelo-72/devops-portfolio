document.addEventListener("DOMContentLoaded", () => {
    const form = document.getElementById("contact-form");
    const message = document.getElementById("form-message");

    form.addEventListener("submit", (event) => {
        event.preventDefault();

        const email = document.getElementById("email").value.trim();

        if (!email) { message.textContent = "Introduza um email válido."; return; }
        message.textContent = "Obrigado. O seu interesse foi registado nesta demonstração.";
        
        form.reset();
    });
});
