# CueConfig
Cue configuration with JSON fallback for Nim projects.

## Description
`cueconfig` is a Nim library that simplifies configuration management by leveraging [CUE](https://cuelang.org/) (Configure Unify Execute). It allows you to define your configuration in CUE, providing powerful validation and schema definition capabilities. It also supports a robust fallback mechanism to JSON and overrides via environment variables.

## Purpose
Enable DRY, deterministic, schema-able, validifiable and scriptable configuration for Nim. Exercise configuration from code for a quicker feedback loop.

## Features
*   **CUE Integration**: Support CUE configuration files.
*   **JSON Fallback**: Automatically falls back to `.json` files if `.cue` files are missing or CUE is not installed.
*   **Hierarchical Configuration**: Merges configuration from multiple sources with a defined precedence order. ENV > Working Dir > Binary Dir > Compile-time.
*   **Compile time access** Access your configuration at compile time or runtime
*   **Compile in config**: Store your config in your compiled binary
*   **Overrides**: Runtime overrides of compiled configuration with environment variables, cue or json files
*   **Live Reloading**: Supports reloading configuration at runtime (trigger with reload())
*   **Type Safety**: Provides a generic `getConfig[T]` procedure to retrieve typed configuration values.
*   **JS Backend Support**: Use compiled in config in JS backend and additionally environment variable overrides in Node.js. Filesystem access limitations mean runtime configuration file use is not supported.

## Installation
Then, install the `cueconfig` package using Nimble:
```bash
nimble install cueconfig
```

## Prerequisites
*   **CUE**: To use CUE files, you need to have `cue` installed and available in your system's PATH. This is not required if you will use pure JSON config,
    *   [Install CUE](https://cuelang.org/docs/install/)


## API
For a config
```cue
frontend: {
  jwt: {
    refresh: period: 36_000
    access: period: 3_600
  }
  spa: {
    routes: {
			home: "/"
			dashboard: "/dashboard"
			profile: "/profile"
		}
  }
}
backend: {
  blacklist: ["100.200.100.200","1.2.3.4"]
  blacklist: [...net.IP]
	db: {
		host: "localhost"
		port: 5432
	}
}
```
Access with
*   `getConfig[T](key: string|openArray[string]|varargs[string]): T`: Retrieves a configuration value by key (dot notation|array/varargs of keys).
*   `reload()`: Reloads the runtime configuration and environment variables. Useful for long-running applications or testing.
*   `showConfig()`: Returns a string representation of the currently loaded configuration.

Valid key formats:
*   Dot notation: `getConfig[int]("frontend.jwt.refresh.period")`
*   Array of strings: `getConfig[int](["frontend", "jwt", "refresh", "period"])`
*   Seq of strings: `getConfig[int](@["frontend", "jwt", "refresh", "period"])`
*   Varargs strings: `getConfig[int]("frontend", "jwt", "refresh", "period")`

## Precedence

`cueconfig` loads configuration from the following sources, in order of precedence (highest to lowest):

1.  **Environment Variables**: Variables starting with `NIM_`.
2.  **Runtime (Working Directory)**: `config.cue` (or `config.json`) in the current working directory. Useful if you want to test your binary with various configs.
3.  **Runtime (Binary Directory)**: `config.cue` (or `config.json`) in the directory where the executable is located.
4.  **Compile-time**: `config.cue` (or `config.json`) in the project root directory at compile time.

## Environment Variables
Environment variables can override any configuration value. The matching logic is as follows:

1.  Prefix: `NIM_` (case-insensitive).
2.  Separator: `_` (underscore) denotes nested keys.
3.  Case Sensitivity: The keys themselves are case-sensitive.

**Examples:**

*   `NIM_SERVER_PORT=9090` overrides `server.port`.
*   `Nim_database_connectionString=...` overrides `database.connectionString`.
*   `nim_app_settings_theme=dark` overrides `app.settings.theme`.
*   `nim_array=[1,2,-.3204e-13]` heterogeneous json array (cast to homogenous nim container)
*   `nim_object={"key1":"value1","key2":2}` json object 

Equivalent cue:
```cue
server: {
	port: 9090
}
database: {
	connectionString: "..."
}
app: {
	settings: {
		theme: "dark"
	}
}	
array: [1, 2, -3.204e-14]
object: {
	key1: "value1"
	key2: 2
}
```

## JSON Fallback
If `config.cue` is not found, `cueconfig` will look for `config.json`. This is useful for deployments where installing the CUE binary might not be desirable or possible.

## License
MIT

## Tests
`nimble test`

## Development AI Usage
AI has been used for dumb code completion, debugging and some documentation. The
logic and architecture is handwritten.