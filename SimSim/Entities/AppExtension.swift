//
//  AppExtension.swift
//  SimSim
//

import Foundation

//============================================================================
class AppExtension
{
    private let uuid: String
    let path: String
    let identifier: String
    
    //----------------------------------------------------------------------------
    var isAppleExtension: Bool
    {
        return identifier.starts(with: "com.apple")
    }
    
    //----------------------------------------------------------------------------
    private init(uuid: String, path: String, identifier: String)
    {
        self.uuid = uuid
        self.path = path
        self.identifier = identifier
    }
    
    //----------------------------------------------------------------------------
    convenience init?(dictionary: [AnyHashable : Any], simulator: Simulator)
    {
        guard let uuid = dictionary[Tools.Keys.fileName] as? String else
        {
            return nil
        }
        
        let path = simulator.pathForAppExtension(withUUID: uuid)
        
        guard let identifier = Tools.containerIdentifier(uuid: uuid, atPath: path) else
        {
            return nil
        }

        self.init(uuid: uuid, path: path, identifier: identifier)
    }
}
