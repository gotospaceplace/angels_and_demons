extends Node

const BUILD_NUMBER := 1
const BUILD_HASH := "7300c85"
const BUILD_DATE := "2026-11-04"
const BUILD_VERSION := "0.1.0"

static func get_build_string() -> String:
	if BUILD_HASH == "dev":
		return "%s-dev" % BUILD_VERSION
	return "%s build %d (%s %s)" % [BUILD_VERSION, BUILD_NUMBER, BUILD_HASH, BUILD_DATE]

static func get_short_string() -> String:
	if BUILD_HASH == "dev":
		return "dev"
	return "#%d-%s" % [BUILD_NUMBER, BUILD_HASH]
