const {onRequest} = require("firebase-functions/v2/https");
const QRCode = require("qrcode");
const logger = require("firebase-functions/logger");

// QR Code Generation Function
exports.generateQr = onRequest(async (req, res) => {
  // Retrieve the data query parameter (e.g., "storeId_userId")
  const data = req.query.data;
  if (!data) {
    res.status(400).json({error: "No data provided"});
    return;
  }
  try {
    // Generate the QR code as a Base64 encoded data URL
    const qrImageData = await QRCode.toDataURL(data);
    // Log the generated data for debugging (optional)
    logger.info("QR Code generated", {data});
    res.json({qrCode: qrImageData});
  } catch (err) {
    logger.error("Error generating QR code", err);
    res.status(500).json({error: "Error generating QR code"});
  }
});
