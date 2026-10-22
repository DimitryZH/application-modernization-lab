using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Xunit;
using cartservice;
namespace cartservice.tests;
public class TelemetryTests
{
 [Fact]
 public async Task CacheActivityRetainsParentAcrossAwait()
 {
  using var listener=new ActivityListener {ShouldListenTo=source=>source.Name=="online-shop.cartservice",Sample=(ref ActivityCreationOptions<ActivityContext> options)=>ActivitySamplingResult.AllDataAndRecorded};
  ActivitySource.AddActivityListener(listener);
  using var parent=Telemetry.Source.StartActivity("test.parent");
  var traceId=parent.TraceId;
  var result=await Telemetry.Cache("read",async()=>{await Task.Yield();Assert.Equal(traceId,Activity.Current.TraceId);Assert.Equal(ActivityKind.Client,Activity.Current.Kind);return 7;});
  Assert.Equal(7,result);Assert.Same(parent,Activity.Current);
 }
}
