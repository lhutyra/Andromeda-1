{-# LANGUAGE ExistentialQuantification #-}
module Simulator.SimulationSpec where

import Lib
import Andromeda
import TestCommon

import Test.Hspec

data In = Initialize
        | SimStateSimpleAction (SimState ())
        | forall v. SimStateReturningAction (SimState v)
        | Start ComponentInstanceIndex
        | Stop ComponentInstanceIndex
data Out = Out String
         | forall v . OutValue v

instance Eq Out where
    Out s1 == Out s2 = s1 == s2
    OutValue v1 == OutValue v2 = False -- TODO
    _ == _ = False
  
instance Show Out where
    show (Out s1) = "Out " ++ s1
    show (OutValue v1) = "OutValue"
  
type SimulatorPipe = Pipe In Out

ok = Out "OK."

process :: Process In Out
process Initialize = return ok
process (SimStateSimpleAction act) = act >> return ok
process (SimStateReturningAction act) = do
    v <- act
    return $ OutValue v

makeRunningSimulation = do
    simModel <- compileSimModel networkDef
    pipe <- createPipe :: IO SimulatorPipe
    simHandle <- startSimulation pipe process simModel
    return (pipe, simHandle)

simulateSingleReq req = do
    (pipe, simHandle) <- makeRunningSimulation
    resp <- sendRequest pipe req
    stopSimulation simHandle
    return resp
    
okOnSuccessAction act = SimStateSimpleAction act
valueOnSuccessAction act = SimStateReturningAction act

runNetworkAct = okOnSuccessAction $ runNetwork
setGen1Act idx = okOnSuccessAction $ setValueGenerator idx floatIncrementGen
getValueSourceAct idx = valueOnSuccessAction $ getValueSource idx

spec = describe "Simulation test" $ do
    it "Initialization should be successfull." $
        simulateSingleReq Initialize `shouldReturn` ok
    it "Setting of value generator to unattached pipe should throw." $ do
        pipe <- createPipe :: IO SimulatorPipe
        sendRequest pipe (setGen1Act boostersNozzle1T) `shouldThrow` anyException
    it "Setting of value generator should be successfull." $
        simulateSingleReq (setGen1Act boostersNozzle1T) `shouldReturn` ok
    it "Continuous simulation of sensor should return values." $ do
        (pipe, simHandle) <- makeRunningSimulation
        r1 <- sendRequest pipe (setGen1Act boostersNozzle1T)
        r2 <- sendRequest pipe runNetworkAct
        vs <- sendRequest pipe (getValueSourceAct boostersNozzle1T)
        
        stopSimulation simHandle
        r1 `shouldBe` ok
        r2 `shouldBe` ok
    -- TODO: setting value gen to non-existent sensor
    