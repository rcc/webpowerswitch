--[[ Tank Controller Script

This script is designed to control aquarium equipment.

Date:    %%%DATE%%%
Version: %%%VERSION%%%

]]--

outlet_names = {"Light","Filter","Heater","Stir Pump"}
outlets = {}

-- Find Outlet
-- Returns the outlet index for a given name
local function find_outlet(name)
  for i=1,8 do
    if outlet[i].name == name then
      return i
    end
  end
  return nil
end

-- Map Outlets By Name
-- Populate global outlet table so they can be referenced by name
local function map_outlets_by_name()
  for i,v in ipairs(outlet_names) do
    local o = find_outlet(v)
    if o then
      log.notice("%s outlet is #%g",v,o)
      outlets[v] = outlet[o]
    end
  end
end

-- Poll Queue Thread
-- Populates a timeout event into all poll queues repeatedly
local function poll_queue_thread()
  while true do
    for _,t,data in event.stream(event.timeout(60)) do
      for i,v in ipairs(poll_queues) do
        v[#v+1] = {t,i}
      end
      break
    end
  end
end

-- Light Thread
-- Thread responsible for managing the light outlet
local function light_thread()
  -- check if there is an outlet to control
  if outlets["Light"] == nil then
    log.warning("No Light outlet found")
    return
  end
  -- this log line is required since this thread must interact with the
  -- outlet before the event change notifications will work
  log.notice("Light outlet state: %s",tostring(outlets["Light"].state))

  -- initialize on_time to now
  local on_time = os.time()
  -- setup our polling event queue
  local pq = event.queue()
  poll_queues[#poll_queues+1] = pq
  -- process events
  for i,t,data in event.stream(
        pq,
        event.change_listener(outlets["Light"]),
        event.local_time({hour=7,min=45}), -- on time
        event.local_time({hour=21,min=00}) -- off time
    ) do
    if i == 1 then -- Poll
      if outlets["Light"].physical_state then
        if os.time() - on_time >= (8*60*60) then
          log.notice("Light timeout, turning off")
          outlets["Light"].persistent_state = off
        end
      end
    elseif i == 2 and data.key == "physical_state" then -- outlet change
      if outlets["Light"].physical_state then
        on_time = os.time()
      end
    elseif i == 3 then -- on time
      log.notice("Light on time")
      outlets["Light"].persistent_state = on
    elseif i == 4 then -- off time
      log.notice("Light off time")
      outlets["Light"].persistent_state = off
    end
  end
end

-- Heater Thread
-- Thread responsible for managing the heater outlet
local function heater_thread()
  -- check if there are the required outlets
  if outlets["Heater"] == nil then
    log.warning("No Heater outlet found")
    return
  end
  if outlets["Filter"] == nil then
    log.warning("No Filter outlet found")
    return
  end

  outlets["Heater"].persistent_state = outlets["Filter"].physical_state
  for i,t,data in event.stream(event.change_listener(outlets["Filter"])) do
    if data.key == "physical_state" then -- outlet change
      delay(5)
      outlets["Heater"].persistent_state = outlets["Filter"].physical_state
    end
  end
end

-- Stir Pump Thread
-- Thread responsible for managing the stir pump outlet
local function stir_thread()
  -- check if there is an outlet to control
  if outlets["Stir Pump"] == nil then
    log.warning("No Stir Pump outlet found")
    return
  end
  -- stir pump should be off by default
  outlets["Stir Pump"].persistent_state = off

  -- initialize on_time to now
  local on_time = os.time()
  -- setup our polling event queue
  local pq = event.queue()
  poll_queues[#poll_queues+1] = pq
  -- process events
  for i,t,data in event.stream(
        pq,
        event.change_listener(outlets["Stir Pump"])
    ) do
    if i == 1 then -- Poll
      if outlets["Stir Pump"].physical_state then
        if os.time() - on_time >= (5*60) then
          log.notice("Stir Pump timeout, turning off")
          outlets["Stir Pump"].off()
        end
      else
        local t = os.date("*t")
        if t.hour >= 9 and t.hour < 17 then
          if os.time() - on_time >= (60*60) then
            log.notice("Stir Pump period, turning on")
            outlets["Stir Pump"].on()
          end
        end
      end
    elseif i == 2 and data.key == "physical_state" then -- outlet change
      if outlets["Stir Pump"].physical_state then
        on_time = os.time()
      end
    end
  end
end

-- Start
-- Script entry script
function start()
  log.notice("Starting scripts")
  map_outlets_by_name()
  poll_queues = {}
  delay(3)
  thread.run(poll_queue_thread,"Poll queue")
  thread.run(light_thread,"Control light outlet")
  thread.run(heater_thread,"Control heater outlet")
  thread.run(stir_thread,"Control stir pump outlet")
end

-- vim: tabstop=2 shiftwidth=2 expandtab
