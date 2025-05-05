// Information to be shown on dashboard route
// 1. If driver has pickup the car and security gate event hasn't happend as
//  start or any next stage hasn't detected then it will be shown as Vehicle about to  arrive workshop drover picked up
// and the moment security gate or any next stage events detects it should be out from that status

//2. the security guard let's the car enter the workshop then the next step is job card creation then it should show as 
// waiting for customer approval and the moment service advisor start jobcard creation it should be out of that status 

// 3. If job card creation has started and bay allocation has not started then that vehicle will be shown as "waiting for allocation status"
// and the moment job controller starts bay allocation the vehcile should be out of this status 

//4. if bay allocaton has bee started and bay work has not been started then the status would be waiting for work to be started 
// and the moment bay work starts it should be out of te status

//5. if work has been started then it should be shown and hasn't ended the  it should be shown as "work in prgress"

//6. if epert stage us happening then it should be shown as under expert

//7. if final inspection has started and not ended then it will be shown as fina inspection till the moment it hasn't ended.

//8. wahsing :  if wahsing has started and not ended then only it should be shown as "IN inspection"

//9. if ready for washing has started and washing has not started then it shpuld be shown as waiting for washing 

// 10 if job card received stage has been triggered by job controller then it should be shown as then completion of work 
// wiating for FI

//11. if washing has ended then and security hasn't ended then it should be shown as waiting for dispactch

//12. if security has ended then it should be shown as car left 
// then it should be shown as Car has been sent to customer and the meoment last tage driverdrop off happens it should out of that 

// 13/ after driver drop off stages vehcile should be remain in delivered stages