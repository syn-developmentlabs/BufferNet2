--[=[
    @class types
    Types for BufferNet

    @author https://github.com/syn-developmentlabs
]=]

export type Options = {
    Ratelimit: number?,
    IsEncrypted: boolean?,
    EncryptionMasterKey: string? -- client
}

export type EncryptionInformation = {
    TunnelStartupTick: number,
    EncryptionMasterKey: string,
}

export type Remote = {
    Type: "Event" | "Function" | "event" | "function" | "unreliableevent",
    Alias: string,
    Instance: RemoteEvent | RemoteFunction | UnreliableRemoteEvent,
    Callback: ((any) -> ()?)?,
    Connection: RBXScriptConnection?,
    Options: Options?,
    EncryptionInformation: EncryptionInformation?
}


return {}