/*
  Unoffical Snapmaker 2.0 post processor for Fusion360
  
  By Darren Allen
  
  Adapted from 'Generic Grbl' (grbl.cps) By AutoDesk & HyperCube.cps By Tech2C

  Last Updated 14:32 GMT 25/Mar/2021
*/

description = "Unoffical Snapmaker 2.0 post processor for Fusion360";
vendor = "Unoffical Snapmaker 2.0";
vendorUrl = "https://github.com/MarlinFirmware/Marlin";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  finishHomeX: false,
  finishPositionY: "",
  finishPositionZ: "",
  rapidTravelXY: 3000,
  rapidTravelZ: 300,
  laserEtch: 128,
  laserVaperize: 255,
  laserThrough: 192,
};

var laserOff ="M5";

var mFormat = createFormat({prefix:"M3 P", decimals:0});
var xyzFormat = createFormat({decimals:3});
var feedFormat = createFormat({decimals:0});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var planeOutput = createVariable({prefix:"G"}, feedFormat);

// circular output
var	iOutput	= createReferenceVariable({prefix:"I"}, xyzFormat);
var	jOutput	= createReferenceVariable({prefix:"J"}, xyzFormat);
var	kOutput	= createReferenceVariable({prefix:"K"}, xyzFormat);

var cuttingMode;

function formatComment(text) {
  return String(text).replace(/[\(\)]/g, "");
}

function writeComment(text) {
  writeWords(formatComment(text));
}

function onOpen() {
  writeln(";***********************************************************************************");
  writeln(";Unoffical Snapmaker 2.0 post processor for Fusion360");
  writeln(";By Darren Allen");
  writeln(";Adapted from 'Generic Grbl' (grbl.cps) By AutoDesk & HyperCube.cps By Tech2C");

  if (programName) {
    writeComment(";Program Name - " + programName);
  }
  if (programComment) {
    writeComment(";Program Comment - " + programComment);
  }

  
  if (properties.laserVaperize <0 || properties.laserVaperize >255)
    {
      error(localize("Laser Vaperize power needs to be set between 0 and 255."));
      return;
    }
    if (properties.laserThrough <0 || properties.laserThrough >255)
    {
      error(localize("Laser Through power needs to be set between 0 and 255."));
      return;
    }
    if (properties.laserEtch <0 || properties.laserEtch >255)
    {
      error(localize("Laser Etch power needs to be set between 0 and 255."));
      return;
    }
    writeWords("M106 P0 S255   ; Turn fan on full");
}


/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {
  if(isFirstSection()) {
    writeWords(laserOff, "           ;Laser Off - Just in case");
    writeWords("G21", "          ;Set to Metric Values");
	  writeWords(planeOutput.format(17), "          ;Set Plane XY");
	  writeWords("G90", "          ;Use Absolute Positioning");
	  writeWords("G92 X0 Y0 Z0", " ;Set XYZ Positions");
	  writeWords("G0", feedOutput.format(properties.rapidTravelXY));
  }

  if (currentSection.getType() == TYPE_JET) {
    switch (currentSection.jetMode) {
    case JET_MODE_THROUGH:

      cuttingMode = "M3 P" + Math.floor((properties.laserThrough/255)*100) + " S" + Math.floor(properties.laserThrough);
      break;
    case JET_MODE_ETCHING:
      cuttingMode = "M3 P" + Math.floor((properties.laserEtch/255)*100) + " S" + Math.floor(properties.laserEtch);
      break;
    case JET_MODE_VAPORIZE:
      cuttingMode = "M3 P" + Math.floor((properties.laserVaperize/255)*100) + " S" + Math.floor(properties.laserVaperize);
      break;
    default:
      error(localize("Unsupported Cutting Mode. Please use Through, Etch or Vaporize"));
      return;     
    }
    } else {
    error(localize("This operation only supports the Snapmaker Laser"));
    return;
    }

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
     writeComment(comment);
    }
  }
}

function onComment(message) {
  writeComment(message);
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeWords("G4 S" + seconds, "        ;Dwell time");
}

function onPower(power) {
  if (power) { writeWords(cuttingMode, "          ;Laser On."); }
  else { writeWords(laserOff, "          ;Laser Off."); }
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y) {
    writeWords("G0", x, y, feedOutput.format(properties.rapidTravelXY));
  }
  if (z) {
    writeWords("G0", z, feedOutput.format(properties.rapidTravelZ));
  }
}

function onLinear(_x, _y, _z, _feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_feed);
  if(x || y || z) {
    writeWords("G1", x, y, z, f);
  }
  else if (f) {
    writeWords("G1", f);
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  error(localize("5-Axis toolpath is not currently supported."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("5-Axis toolpath is not currently supported."));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // one of X/Y and I/J are required and likewise
  var start = getCurrentPosition();
  
  if (isHelical()) {
    linearize(tolerance);
    return;
  }

  switch (getCircularPlane()) {
  case PLANE_XY:
    writeWords(planeOutput.format(17), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
    break;
  case PLANE_ZX:
    writeWords(planeOutput.format(18), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
    break;
  case PLANE_YZ:
    writeWords(planeOutput.format(19), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
	break;
  default:
    linearize(tolerance);
  }
}

function onSectionEnd() {
  if (getPower()) {writeWords(laserOff, "         ;Laser Off");}
  writeWords(planeOutput.format(17));
  forceAny();
}

function onClose() {
  writeWords("M400");
  if (getPower()) {writeWords(laserOff, "         ;Laser Off");}
  if(properties.finishPositionZ) { writeWords("G0 Z" + properties.finishPositionZ, feedOutput.format(properties.rapidTravelZ), "   ;Position Z"); }
  writeWords("G0", feedOutput.format(properties.rapidTravelXY));
  if(properties.finishHomeX) { writeWords("G28 X", "        ;Home X"); }
  if(properties.finishPositionY) { writeWords("G0 Y" + properties.finishPositionY, "      ;Position Y"); }
  writeWords("M107 P0    ;Turn Fan Off");
}