--[=[
    @class Utilities
    Utilities for BufferNet

    @author https://github.com/syn-developmentlabs
]=]

return {
    assertTypes = function(expectedType: string | {string}, value: any, argIndex: number)
        local functionName = debug.info(2, "s")

        if typeof(expectedType) == "string" then
            return assert(
                typeof(value):lower() == expectedType:lower(),
                `Expected {expectedType} when calling {functionName} at paramater #{argIndex}, found {typeof(value)}`,
                2
            )
        elseif typeof(expectedType) == "table" and #expectedType > 0 then
            return assert(
                table.find(expectedType, value),
                `Expected {table.concat(expectedType, ' OR ')} when calling {functionName} at paramater #{argIndex}, found {typeof(value)} ({tostring(value)})`
            )
        end

        return error("Failed to assert types", 2)
    end,
    generateRandomString = function(length: number): string
        local str = ""        
        for i = 1, length do
            str = str.. string.char(math.random(0, 255))
        end

        return str
    end
}