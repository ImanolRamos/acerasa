const app = require("./app");

const PORT = process.env.PORT || 3000;
const CLIENT_NAME = process.env.CLIENT_NAME || "koiote";

app.listen(PORT, "0.0.0.0", () => {
  console.log(`[OK] Backend escuchando en el puerto ${PORT} — cliente: ${CLIENT_NAME}`);
})