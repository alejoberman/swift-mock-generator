* Architecture *

SwiftSyntax
     │
     ▼
ProtocolDescriptor
     │
     ▼
MockModel
     │
     ▼
MockToSwiftTransformer
     │              │
     │              ▼
     │        TypeTransformer
     │
     ▼
SwiftFile
     │
     ▼
SwiftEmitter
     │
     ▼
Generated Swift
