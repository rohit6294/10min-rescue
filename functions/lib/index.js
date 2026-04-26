"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onSosCreated = exports.updateDriverLocation = exports.onHospitalTimeout = exports.onHospitalAccept = exports.findNearbyHospitals = exports.onDriverTimeout = exports.onDriverAccept = exports.findNearbyDrivers = void 0;
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
// Export all functions
var findNearbyDrivers_1 = require("./findNearbyDrivers");
Object.defineProperty(exports, "findNearbyDrivers", { enumerable: true, get: function () { return findNearbyDrivers_1.findNearbyDrivers; } });
var onDriverAccept_1 = require("./onDriverAccept");
Object.defineProperty(exports, "onDriverAccept", { enumerable: true, get: function () { return onDriverAccept_1.onDriverAccept; } });
var onDriverTimeout_1 = require("./onDriverTimeout");
Object.defineProperty(exports, "onDriverTimeout", { enumerable: true, get: function () { return onDriverTimeout_1.onDriverTimeout; } });
var findNearbyHospitals_1 = require("./findNearbyHospitals");
Object.defineProperty(exports, "findNearbyHospitals", { enumerable: true, get: function () { return findNearbyHospitals_1.findNearbyHospitals; } });
var onHospitalAccept_1 = require("./onHospitalAccept");
Object.defineProperty(exports, "onHospitalAccept", { enumerable: true, get: function () { return onHospitalAccept_1.onHospitalAccept; } });
var onHospitalTimeout_1 = require("./onHospitalTimeout");
Object.defineProperty(exports, "onHospitalTimeout", { enumerable: true, get: function () { return onHospitalTimeout_1.onHospitalTimeout; } });
var updateDriverLocation_1 = require("./updateDriverLocation");
Object.defineProperty(exports, "updateDriverLocation", { enumerable: true, get: function () { return updateDriverLocation_1.updateDriverLocation; } });
var onSosCreated_1 = require("./onSosCreated");
Object.defineProperty(exports, "onSosCreated", { enumerable: true, get: function () { return onSosCreated_1.onSosCreated; } });
//# sourceMappingURL=index.js.map