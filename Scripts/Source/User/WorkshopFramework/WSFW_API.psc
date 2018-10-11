; ---------------------------------------------
; WorkshopFramework:WSFW_API.psc - by kinggath
; ---------------------------------------------
; Reusage Rights ------------------------------
; You are free to use this script or portions of it in your own mods, provided you give me credit in your description and maintain this section of comments in any released source code (which includes the IMPORTED SCRIPT CREDIT section to give credit to anyone in the associated Import scripts below.
; 
; Warning !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; Do not directly recompile this script for redistribution without first renaming it to avoid compatibility issues issues with the mod this came from.
; 
; IMPORTED SCRIPT CREDIT
; N/A
; ---------------------------------------------

Scriptname WorkshopFramework:WSFW_API Hidden Const

import WorkshopFramework:Library:DataStructures
import WorkshopFramework:Library:UtilityFunctions


; ------------------------------
; CreateSettlementObject_Threaded 
;
; Description: Creates a settlement object as if the player built it in workshop mode, and returns the reference, or None if it failed.
;
;
; Parameters:
; PlaceMe - Your objects should be in an array of structs per the WorldObject definition found in Library:DataStructures.
;
; akWorkshopRef [Optional] - The objectreference of the settlement workbench cast as WorkshopScript. If this is not sent, the object will not be linked to the workshop. The Link is what allows several gameplay elements: Player Scrapping, Crafting Stations to share resources, Assignable objects to be assignable, and more.
; 
; akPositionRelativeTo [Optional] - It the positions in your PlaceMe data are offsets from a specific reference, send that reference (note that this increases the processing time by about 40%, so sending world coordinates is definitely preferred)
;
; abStartEnabled [Optional] - If you would like to handle enabling the objects yourself, set this to false
; ------------------------------

ObjectReference Function CreateSettlementObject(WorldObject PlaceMe, WorkshopScript akWorkshopRef = None, ObjectReference akPositionRelativeTo = None, Bool abStartEnabled = true) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	return API.PlaceObjectManager.CreateObjectImmediately(PlaceMe, akWorkshopRef, None, -1, akPositionRelativeTo, abStartEnabled)
EndFunction



; ------------------------------
; CreateSettlementObject_Threaded 
;
; Description: Faster version of CreateSettlementObject. Creates a settlement object as if the player built it in workshop mode, and returns the CallbackID integer you should watch for if you included akRegisterMeForEvent and need to know about the reference.
;
; Prepare to receive CustomEvent WorkshopFramework:Library:ThreadRunner.OnThreadCompleted (which your akRegisterMeForEvent will be automatically registered for if you sent it). 
; 
; When receiving the event you should confirm that kArgs[0] == the CallbackID you received from this call and kArgs[1] will equal the ObjectReference to your created item.
; 
;
; Parameters:
; PlaceMe - Your objects should be in an array of structs per the WorldObject definition found in Library:DataStructures.
;
; akWorkshopRef [Optional] - The objectreference of the settlement workbench cast as WorkshopScript. If this is not sent, the object will not be linked to the workshop. The Link is what allows several gameplay elements: Player Scrapping, Crafting Stations to share resources, Assignable objects to be assignable, and more.
; 
; akPositionRelativeTo [Optional] - It the positions in your PlaceMe data are offsets from a specific reference, send that reference (note that this increases the processing time by about 40%, so sending world coordinates is definitely preferred)
;
; abStartEnabled [Optional] - If you would like to handle enabling the objects yourself, set this to false
; 
; akRegisterMeForEvent [Optional] - The object or quest you would like to receive the WorkshopFramework:PlaceObjectManager.ObjectBatchCreated events. If you don't need to track the items, leave this field as None.
; ------------------------------

Int Function CreateSettlementObject_Threaded(WorldObject PlaceMe, WorkshopScript akWorkshopRef = None, ObjectReference akPositionRelativeTo = None, Bool abStartEnabled = true, Form akRegisterMeForEvent = None) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return -1
	endif
	
	Bool bRequestEvents = false
	if(akRegisterMeForEvent)
		akRegisterMeForEvent.RegisterForCustomEvent(API.PlaceObjectManager, "ObjectBatchCreated")
		bRequestEvents = true
	endif
	
	int iBatchID = API.PlaceObjectManager.CreateObject(PlaceMe, akWorkshopRef, None, -1, akPositionRelativeTo, abStartEnabled, bRequestEvents)
	
	return iBatchID
EndFunction


; ------------------------------
; RemoveSettlementObject 
;
; Description: This effectively scraps an object, with everything except the provision of resourced. It handles all of the other required background activity to remove a settlement object safely. Done via thread engine.
; 
;
; Parameters:
; ObjectReference akRemoveRef - The objectreference to remove. 
;
; Form akRegisterMeForEvent [Optional] - The object or quest you would like to receive the WorkshopFramework:PlaceObjectManager.ObjectRemoved events. If you don't need to track the items, leave this field as None.
; ------------------------------

Int Function RemoveSettlementObject(ObjectReference akRemoveRef, Form akRegisterMeForEvent = None) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return -1
	endif
	
	Bool bRequestEvents = false
	if(akRegisterMeForEvent)
		akRegisterMeForEvent.RegisterForCustomEvent(API.PlaceObjectManager, "ObjectRemoved")
		bRequestEvents = true
	endif
	
	int iBatchID = API.PlaceObjectManager.ScrapObject(akRemoveRef, bRequestEvents)
	
	return iBatchID
EndFunction


; -----------------------------------
; SpawnWorkshopNPC
;
; Description: Spawns an NPC at the targeted settlement.
;
; Parameters:
; WorkshopScript akWorkshopRef - the settlement workshop to spawn at
; 
; Bool abBrahmin - Whether this should be a brahmin or a settler
;
; ActorBase aActorFormOverride - Allows you to spawn a custom NPC. Make sure that the Actor form you are sending has the WorkshopNPCScript attached and configured!
;
; Returns:
; Created NPC ref
; -----------------------------------

WorkshopNPCScript Function SpawnWorkshopNPC(WorkshopScript akWorkshopRef, Bool abBrahmin = false, ActorBase aActorFormOverride = None) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	if(aActorFormOverride != None)
		return API.NPCManager.CreateWorkshopNPC(aActorFormOverride, akWorkshopRef)
	elseif(abBrahmin)
		return API.NPCManager.CreateBrahmin(akWorkshopRef)
	else
		return API.NPCManager.CreateSettler(akWorkshopRef)
	endif
EndFunction


; -----------------------------------
; RegisterResourceProductionType
; 
; Description: Registers a Resource type ActorValue to produce a certain resource each day based on how much of that resource exists in a settlement. Similar to how Food and Water values cause settlements to create extra crops and water in the Workbench each day
;
; Parameters:
; LeveledItem aProduceMe - The leveleditem to produce. Note that 1 will be produced for each point of the resource found.
; 
; ActorValue aResourceAV - The ActorValue to check the settlement for. If you want workshop objects to be able to provide this resource, ensure the ActorValue you use/create is of the Resource type (it's a drop down menu on the Actor Value edit window in the CK), then on the workshop object add that actor value and the amount you want it to produce. You also need to add the ActorValue WorkshopResourceObject with a value of 1, which is how the game knows to grab that item when calculating total resources for the settlement.
;
; Keyword aTargetContainerKeyword - [Optional] If you want to flag your produced items as a particular type, for example as food, set the matching container keyword (see the documentation regarding the Workshop Container system). You can also use this to force your items to be sorted into a particular container type in the Workshop Container system, assuming players are using said containers.
; -----------------------------------

Function RegisterResourceProductionType(LeveledItem aProduceMe, ActorValue aResourceAV, Keyword aTargetContainerKeyword = None) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	API.WorkshopProductionManager.RegisterProductionResource(aProduceMe, aResourceAV, aTargetContainerKeyword)
EndFunction


; Reverse a RegisterResourceProductionType call
Function UnregisterResourceProductionType(LeveledItem aProduceMe, ActorValue aResourceAV) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	API.WorkshopProductionManager.UnregisterProductionResource(aProduceMe, aResourceAV)
EndFunction


; -----------------------------------
; RegisterResourceConsumptionType
; 
; Description: Registers a Resource type ActorValue to be consumed each day based on how much of that resource exists in a settlement. This allows adding costs to virtually anything. For example, you could define a fuel resource actor value and assign it to generators so they consumed gasoline each day.

; Notes: There is no inherit penalty if a settlement fails to have enough resources to be consumed each day, you will have to define that penalty. During each day's consumption, if anything is missing, a custom event will be fired you can watch for and act on. The event is called "NotEnoughResources" and will come from the WorkshopFramework:WorkshopProductionManager quest.
;
; Parameters:
; Form aConsumeMe - The Form to consume. Note that 1 will be consumed for each point of the resource found. This Form can be any of the following: Keyword - will consume anything with an object type matching that keyword, FormList - will consume anything found on that formlist, Component or MiscItem or Weapon or Ammo or Armor or WeaponMod - will consume that specific thing.
; 
; ActorValue aResourceAV - The ActorValue to check the settlement for. If you want workshop objects to be able to consume this resource, ensure the ActorValue you use/create is of the Resource type (it's a drop down menu on the Actor Value edit window in the CK), then on the workshop object add that actor value and the amount you want it to consume. You also need to add the ActorValue WorkshopResourceObject with a value of 1, which is how the game knows to grab that item when calculating total resources for the settlement.
;
; Keyword aSearchContainerKeyword - [Optional] If you want to search a particular container keyword (see the documentation regarding the Workshop Container system). You can also use this to check that container type specifically, otherwise it will just check the workbench.
;
; Bool abIsComponentFormList - If you used a Formlist of components as aConsumeMe, change this to true. This will ensure the game correctly breaks down junk and consumes the pieces.
; -----------------------------------

Function RegisterResourceConsumptionType(Form aConsumeMe, ActorValue aResourceAV, Keyword aSearchContainerKeyword = None, Bool abIsComponentFormList = false) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	API.WorkshopProductionManager.RegisterConsumptionResource(aConsumeMe, aResourceAV, aSearchContainerKeyword, abIsComponentFormList)
EndFunction

; Reverse a RegisterConsumptionResourceType call
Function UnregisterResourceConsumptionType(Form aConsumeMe, ActorValue aResourceAV) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	API.WorkshopProductionManager.UnregisterConsumptionResource(aConsumeMe, aResourceAV)
EndFunction

	
; -----------------------------------
; IsPlayerInWorkshopMode
; -----------------------------------

Bool Function IsPlayerInWorkshopMode() global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	WorkshopScript workshopRef = API.WSFW_Main.LastWorkshopAlias.GetRef() as WorkshopScript
	
	if(workshopRef)
		return workshopRef.UFO4P_InWorkshopMode
	else
		return false
	endif
EndFunction


; -----------------------------------
; GetNearestWorkshop
;
; Description: Grabs closest WorkshopScript reference - with some exceptions. If the object is linked to a settlement, it will grab that workshop. If an object is in a workshop's location, it will grab that. Lastly, it will search in a radius to find the closest.
; -----------------------------------

WorkshopScript Function GetNearestWorkshop(ObjectReference akToRef) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	WorkshopScript nearestWorkshop = akToRef.GetLinkedRef(API.WorkshopItemKeyword) as WorkshopScript
	if( ! nearestWorkshop)	
		WorkshopParentScript WorkshopParent = API.WorkshopParent
		Location thisLocation = akToRef.GetCurrentLocation()
		nearestWorkshop = WorkshopParent.GetWorkshopFromLocation(thisLocation)
		
		if( ! nearestWorkshop)
			ObjectReference[] WorkshopsNearby = akToRef.FindAllReferencesWithKeyword(API.WorkshopKeyword, 20000.0)
			int i = 0
			while(i < WorkshopsNearby.Length)
				if(nearestWorkshop)
					if(WorkshopsNearby[i].GetDistance(akToRef) < nearestWorkshop.GetDistance(akToRef))
						nearestWorkshop = WorkshopsNearby[i] as WorkshopScript
					endIf
				else
					nearestWorkshop = WorkshopsNearby[i] as WorkshopScript
				endif
				
				i += 1
			EndWhile
		endif
	endif
	
	return nearestWorkshop
EndFunction


	; -----------------------------------
	; -----------------------------------
	; Third Party Integration Functions
	; -----------------------------------
	; -----------------------------------
	

; -----------------------------------
; IsF4SERunning
; -----------------------------------

Bool Function IsF4SERunning() global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return None
	endif
	
	return API.F4SEManager.IsF4SERunning
EndFunction



	; -----------------------------------
	; -----------------------------------
	; Advanced
	; -----------------------------------
	; -----------------------------------


; ------------------------------
; CreateBatchSettlementObjects
;
; Description: Creates a batch of settlement objects through the thread manager and returns the batch ID to expect via custom event. This will be much faster than creating indivdual objects, but requires planning for batch-based event handling.
;
; Prepare to receive CustomEvent WorkshopFramework:PlaceObjectManager.ObjectBatchCreated (which your akRegisterMeForEvent will be automatically registered for if you sent it). Object refs will be sent via that event in batches. The Var contents will be as follows:
;    kArgs[0] = ActorValue items are tagged with, kArgs[1] = Value of tagged ActorValue, kArgs[2] = Whether or not to expect additional items in this batch, kArgs[3 through 127] = ObjectReferences of your created objects.
; 
; When receiving the event you should confirm that kArgs[0] == GetDefaultPlaceObjectsBatchAV() (from this API) and kArgs[1] == the batch Id return value you received from this function.
; 
;
; Parameters:
; PlaceMe - Your objects should be in an array of structs per the WorldObject definition found in Library:DataStructures.
;
; akPositionRelativeTo [Optional] - It the positions in your PlaceMe data are offsets from a specific reference
;
; abStartEnabled [Optional] - If you would like to handle enabling the objects yourself, set this to false
; 
; akRegisterMeForEvent [Optional] - The object or quest you would like to receive the WorkshopFramework:PlaceObjectManager.ObjectBatchCreated events. If you don't need to track the items, leave this field as None.
; ------------------------------

Int Function CreateBatchSettlementObjects(WorldObject[] PlaceMe, WorkshopScript akWorkshopRef = None, ObjectReference akPositionRelativeTo = None, Bool abStartEnabled = true, Form akRegisterMeForEvent = None) global
	WorkshopFramework:WSFW_APIQuest API = GetAPI()
	
	if( ! API)
		Debug.Trace("[WSFW] Failed to get API.")
		return -1
	endif
	
	Bool bRequestEvents = false
	if(akRegisterMeForEvent)
		Debug.Trace("[WSFW] Registering for ObjectBatchCreated events.")
		akRegisterMeForEvent.RegisterForCustomEvent(API.PlaceObjectManager, "ObjectBatchCreated")
		bRequestEvents = true
	endif
	
	int iBatchID = API.PlaceObjectManager.CreateBatchObjects(PlaceMe, akWorkshopRef, None, akPositionRelativeTo, abStartEnabled, bRequestEvents)
	
	return iBatchID
EndFunction


; ------------------------------
; GetDefaultPlaceObjectsBatchAV
;
; Description: Grabs the default AV to expect from the WorkshopFramework:PlaceObjectManager.ObjectBatchCreated event so you can check that the event data matches what your object is expecting
; ------------------------------
ActorValue Function GetDefaultPlaceObjectsBatchAV() global
	return Game.GetFormFromFile(0x00004CA2, "WorkshopFramework.esm") as ActorValue
EndFunction



	; -----------------------------------
	; -----------------------------------
	; Do NOT Use - Functions below here are needed by this API script only
	; -----------------------------------
	; -----------------------------------	



; ------------------------------
; GetAPI
;
; Description: Used internally by these functions to get simple access to properties
; ------------------------------

WorkshopFramework:WSFW_APIQuest Function GetAPI() global
	WorkshopFramework:WSFW_APIQuest API = Game.GetFormFromFile(0x00004CA3, "WorkshopFramework.esm") as WorkshopFramework:WSFW_APIQuest
	
	if( ! (API.MasterQuest as WorkshopFramework:MainQuest).bFrameworkReady)
		if(API.MasterQuest.SafeToStartFrameworkQuests()) 
			Utility.WaitMenuMode(0.1)
		else
			; Player still hasn't reached a point where the quests are ready to start - let's not queue these up
			return None
		endif
	endif
	
	return API
EndFunction