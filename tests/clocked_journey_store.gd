extends "res://scripts/journey_store_native.gd"
## Test-only logical clock. Never changes production lease duration or validation.
## Optional delay reproduces slow filesystem/runner scheduling without consuming
## the logical lease; tests advance time only at explicit boundaries.
var now_ms:int=2000000000000
var delay_ms:int=0
func _init(path:String):
 super(path)
func _now()->int:return now_ms
func _mutate(op:String,args:Dictionary)->Dictionary:
 if delay_ms>0:OS.delay_msec(delay_ms)
 return super._mutate(op,args)
