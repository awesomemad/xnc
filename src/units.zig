const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;

pub const UnitCategory = enum {
    length,
    mass,
    time,
    temperature,
    pressure,
    volume,
    speed,
    energy,
    area,
    digital,
    angle,
    frequency,
    force,
    power,
    electric_current,
    luminous_intensity,
    amount,
    unknown,
};

pub const UnitDef = struct {
    name: []const u8,
    aliases: []const []const u8,
    category: UnitCategory,
    to_si: f64,
    offset: f64 = 0.0,
};

const si_units = [_]UnitDef{
    .{ .name = "m", .aliases = &.{"meter", "meters"}, .category = .length, .to_si = 1.0 },
    .{ .name = "km", .aliases = &.{"kilometer", "kilometers"}, .category = .length, .to_si = 1000.0 },
    .{ .name = "cm", .aliases = &.{"centimeter", "centimeters"}, .category = .length, .to_si = 0.01 },
    .{ .name = "mm", .aliases = &.{"millimeter", "millimeters"}, .category = .length, .to_si = 0.001 },
    .{ .name = "um", .aliases = &.{"micrometer", "micrometers", "micron"}, .category = .length, .to_si = 1e-6 },
    .{ .name = "nm", .aliases = &.{"nanometer", "nanometers"}, .category = .length, .to_si = 1e-9 },
    .{ .name = "in", .aliases = &.{"inch", "inches", "\""}, .category = .length, .to_si = 0.0254 },
    .{ .name = "ft", .aliases = &.{"foot", "feet", "'"}, .category = .length, .to_si = 0.3048 },
    .{ .name = "yd", .aliases = &.{"yard", "yards"}, .category = .length, .to_si = 0.9144 },
    .{ .name = "mi", .aliases = &.{"mile", "miles"}, .category = .length, .to_si = 1609.344 },
    .{ .name = "nmi", .aliases = &.{"nautical_mile", "nautical_miles"}, .category = .length, .to_si = 1852.0 },
    .{ .name = "au", .aliases = &.{"astronomical_unit", "AU"}, .category = .length, .to_si = 1.495978707e11 },
    .{ .name = "ly", .aliases = &.{"light_year", "light_years"}, .category = .length, .to_si = 9.4607304725808e15 },
    .{ .name = "pc", .aliases = &.{"parsec", "parsecs"}, .category = .length, .to_si = 3.085677581e16 },
    .{ .name = "angstrom", .aliases = &.{"Å", "angstroms"}, .category = .length, .to_si = 1e-10 },

    .{ .name = "kg", .aliases = &.{"kilogram", "kilograms"}, .category = .mass, .to_si = 1.0 },
    .{ .name = "g", .aliases = &.{"gram", "grams"}, .category = .mass, .to_si = 0.001 },
    .{ .name = "mg", .aliases = &.{"milligram", "milligrams"}, .category = .mass, .to_si = 1e-6 },
    .{ .name = "lb", .aliases = &.{"pound", "pounds", "lbs"}, .category = .mass, .to_si = 0.45359237 },
    .{ .name = "oz", .aliases = &.{"ounce", "ounces"}, .category = .mass, .to_si = 0.028349523125 },
    .{ .name = "ton", .aliases = &.{"tonne", "metric_ton"}, .category = .mass, .to_si = 1000.0 },
    .{ .name = "st", .aliases = &.{"stone", "stones"}, .category = .mass, .to_si = 6.35029318 },

    .{ .name = "s", .aliases = &.{"second", "seconds", "sec"}, .category = .time, .to_si = 1.0 },
    .{ .name = "ms", .aliases = &.{"millisecond", "milliseconds"}, .category = .time, .to_si = 0.001 },
    .{ .name = "us", .aliases = &.{"microsecond", "microseconds"}, .category = .time, .to_si = 1e-6 },
    .{ .name = "ns", .aliases = &.{"nanosecond", "nanoseconds"}, .category = .time, .to_si = 1e-9 },
    .{ .name = "min", .aliases = &.{"minute", "minutes"}, .category = .time, .to_si = 60.0 },
    .{ .name = "hr", .aliases = &.{"hour", "hours", "h"}, .category = .time, .to_si = 3600.0 },
    .{ .name = "day", .aliases = &.{"days", "d"}, .category = .time, .to_si = 86400.0 },
    .{ .name = "wk", .aliases = &.{"week", "weeks"}, .category = .time, .to_si = 604800.0 },
    .{ .name = "yr", .aliases = &.{"year", "years", "annum"}, .category = .time, .to_si = 31557600.0 },

    .{ .name = "K", .aliases = &.{"kelvin", "kelvins"}, .category = .temperature, .to_si = 1.0 },
    .{ .name = "C", .aliases = &.{"celsius", "degC"}, .category = .temperature, .to_si = 1.0, .offset = 273.15 },
    .{ .name = "F", .aliases = &.{"fahrenheit", "degF"}, .category = .temperature, .to_si = 0.5555555555555556, .offset = 255.3722222222222 },

    .{ .name = "Pa", .aliases = &.{"pascal", "pascals"}, .category = .pressure, .to_si = 1.0 },
    .{ .name = "kPa", .aliases = &.{"kilopascal", "kilopascals"}, .category = .pressure, .to_si = 1000.0 },
    .{ .name = "MPa", .aliases = &.{"megapascal", "megapascals"}, .category = .pressure, .to_si = 1e6 },
    .{ .name = "bar", .aliases = &.{"bars"}, .category = .pressure, .to_si = 100000.0 },
    .{ .name = "atm", .aliases = &.{"atmosphere", "atmospheres"}, .category = .pressure, .to_si = 101325.0 },
    .{ .name = "psi", .aliases = &.{"pounds_per_sq_inch"}, .category = .pressure, .to_si = 6894.757293168 },
    .{ .name = "mmHg", .aliases = &.{"torr", "mmHg"}, .category = .pressure, .to_si = 133.322368421 },

    .{ .name = "L", .aliases = &.{"liter", "liters", "litre", "litres", "l"}, .category = .volume, .to_si = 0.001 },
    .{ .name = "mL", .aliases = &.{"milliliter", "milliliters"}, .category = .volume, .to_si = 1e-6 },
    .{ .name = "gal", .aliases = &.{"gallon", "gallons"}, .category = .volume, .to_si = 0.003785411784 },
    .{ .name = "qt", .aliases = &.{"quart", "quarts"}, .category = .volume, .to_si = 0.000946352946 },
    .{ .name = "cup", .aliases = &.{"cups"}, .category = .volume, .to_si = 0.0002365882365 },
    .{ .name = "floz", .aliases = &.{"fluid_ounce", "fluid_ounces"}, .category = .volume, .to_si = 2.95735295625e-5 },
    .{ .name = "tbsp", .aliases = &.{"tablespoon", "tablespoons"}, .category = .volume, .to_si = 1.478676478125e-5 },
    .{ .name = "tsp", .aliases = &.{"teaspoon", "teaspoons"}, .category = .volume, .to_si = 4.92892159375e-6 },

    .{ .name = "mps", .aliases = &.{"meter_per_second", "m/s"}, .category = .speed, .to_si = 1.0 },
    .{ .name = "kph", .aliases = &.{"km/h", "kmh", "kilometer_per_hour"}, .category = .speed, .to_si = 0.2777777777777778 },
    .{ .name = "mph", .aliases = &.{"mile_per_hour", "mi/h"}, .category = .speed, .to_si = 0.44704 },
    .{ .name = "knot", .aliases = &.{"knots", "kn"}, .category = .speed, .to_si = 0.5144444444444445 },
    .{ .name = "c", .aliases = &.{"lightspeed"}, .category = .speed, .to_si = 299792458.0 },

    .{ .name = "J", .aliases = &.{"joule", "joules"}, .category = .energy, .to_si = 1.0 },
    .{ .name = "cal", .aliases = &.{"calorie", "calories"}, .category = .energy, .to_si = 4.184 },
    .{ .name = "kcal", .aliases = &.{"kilocalorie", "kilocalories"}, .category = .energy, .to_si = 4184.0 },
    .{ .name = "BTU", .aliases = &.{"btu", "British_thermal_unit"}, .category = .energy, .to_si = 1055.056 },
    .{ .name = "kWh", .aliases = &.{"kilowatt_hour", "kilowatt_hours"}, .category = .energy, .to_si = 3.6e6 },
    .{ .name = "eV", .aliases = &.{"electronvolt", "electron_volts"}, .category = .energy, .to_si = 1.602176634e-19 },

    .{ .name = "m2", .aliases = &.{"square_meter", "sq_m"}, .category = .area, .to_si = 1.0 },
    .{ .name = "ha", .aliases = &.{"hectare", "hectares"}, .category = .area, .to_si = 10000.0 },
    .{ .name = "acre", .aliases = &.{"acres"}, .category = .area, .to_si = 4046.8564224 },

    .{ .name = "B", .aliases = &.{"byte", "bytes"}, .category = .digital, .to_si = 1.0 },
    .{ .name = "KB", .aliases = &.{"kilobyte", "kilobytes"}, .category = .digital, .to_si = 1000.0 },
    .{ .name = "MB", .aliases = &.{"megabyte", "megabytes"}, .category = .digital, .to_si = 1e6 },
    .{ .name = "GB", .aliases = &.{"gigabyte", "gigabytes"}, .category = .digital, .to_si = 1e9 },
    .{ .name = "TB", .aliases = &.{"terabyte", "terabytes"}, .category = .digital, .to_si = 1e12 },
    .{ .name = "KiB", .aliases = &.{"kibibyte", "kibibytes"}, .category = .digital, .to_si = 1024.0 },
    .{ .name = "MiB", .aliases = &.{"mebibyte", "mebibytes"}, .category = .digital, .to_si = 1048576.0 },
    .{ .name = "GiB", .aliases = &.{"gibibyte", "gibibytes"}, .category = .digital, .to_si = 1073741824.0 },

    .{ .name = "deg", .aliases = &.{"degree", "degrees", "°"}, .category = .angle, .to_si = std.math.pi / 180.0 },
    .{ .name = "rad", .aliases = &.{"radian", "radians"}, .category = .angle, .to_si = 1.0 },
    .{ .name = "grad", .aliases = &.{"gradian", "gradians", "gon"}, .category = .angle, .to_si = std.math.pi / 200.0 },

    .{ .name = "Hz", .aliases = &.{"hertz"}, .category = .frequency, .to_si = 1.0 },
    .{ .name = "kHz", .aliases = &.{"kilohertz"}, .category = .frequency, .to_si = 1000.0 },
    .{ .name = "MHz", .aliases = &.{"megahertz"}, .category = .frequency, .to_si = 1e6 },
    .{ .name = "GHz", .aliases = &.{"gigahertz"}, .category = .frequency, .to_si = 1e9 },
};

pub const UnitConverter = struct {
    units: std.StringHashMap(UnitDef),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UnitConverter {
        var self = UnitConverter{
            .units = std.StringHashMap(UnitDef).init(allocator),
            .allocator = allocator,
        };
        for (&si_units) |unit| {
            self.units.put(unit.name, unit) catch {};
            for (unit.aliases) |alias| {
                self.units.put(alias, unit) catch {};
            }
        }
        return self;
    }

    pub fn deinit(self: *UnitConverter) void {
        self.units.deinit();
    }

    pub fn findUnit(self: *UnitConverter, name: []const u8) ?UnitDef {
        return self.units.get(name);
    }

    pub fn convert(self: *UnitConverter, value: f64, from: []const u8, to: []const u8) !ConversionResult {
        const from_unit = self.findUnit(from) orelse return error.UnknownUnit;
        const to_unit = self.findUnit(to) orelse return error.UnknownUnit;
        if (from_unit.category != to_unit.category) return error.UnitMismatch;

        const si_value = value * from_unit.to_si + from_unit.offset;
        const result = (si_value - to_unit.offset) / to_unit.to_si;

        return ConversionResult{
            .value = result,
            .from_unit = from_unit.name,
            .to_unit = to_unit.name,
            .category = from_unit.category,
            .from_original = value,
        };
    }

    pub fn listUnits(_: *UnitConverter, _: ?UnitCategory) void {
    }

    pub fn formatResult(self: *UnitConverter, result: ConversionResult) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{d:.6} {s} = {d:.6} {s}",
            .{ result.from_original, result.from_unit, result.value, result.to_unit });
    }
};

pub const ConversionResult = struct {
    value: f64,
    from_unit: []const u8,
    to_unit: []const u8,
    category: UnitCategory,
    from_original: f64,
};
