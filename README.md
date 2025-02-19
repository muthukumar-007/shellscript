using System;
using System.Threading;
using System.Threading.Tasks;
using RedLockNet;
using RedLockNet.SERedis;
using RedLockNet.SERedis.Configuration;

class Program
{
    private static readonly string LockKey = "my_redlock_resource";
    private static readonly TimeSpan LockDuration = TimeSpan.FromSeconds(10); // Lock expires in 10s
    private static readonly TimeSpan RenewBefore = TimeSpan.FromSeconds(3);   // Renew lock 3s before expiry
    private static readonly CancellationTokenSource cts = new();

    static async Task Main()
    {
        var redisEndpoints = new[]
        {
            new RedLockEndPoint { EndPoint = new System.Net.IPEndPoint(System.Net.IPAddress.Parse("127.0.0.1"), 6379) },
            new RedLockEndPoint { EndPoint = new System.Net.IPEndPoint(System.Net.IPAddress.Parse("127.0.0.1"), 6380) },
            new RedLockEndPoint { EndPoint = new System.Net.IPEndPoint(System.Net.IPAddress.Parse("127.0.0.1"), 6381) }
        };

        using var redlockFactory = RedLockFactory.Create(redisEndpoints);

        Console.WriteLine("🚀 Trying to acquire the lock...");

        // Start the lock renewal process
        await AcquireAndExtendLock(redlockFactory);
    }

    /// <summary>
    /// Acquires and extends RedLock before expiry.
    /// </summary>
    private static async Task AcquireAndExtendLock(RedLockFactory redlockFactory)
    {
        while (!cts.Token.IsCancellationRequested)
        {
            using (var redLock = await redlockFactory.CreateLockAsync(LockKey, LockDuration))
            {
                if (redLock.IsAcquired)
                {
                    Console.WriteLine("🔒 Lock acquired!");

                    // Start a background task to renew the lock
                    var renewalTask = RenewLockAsync(redlockFactory, cts.Token);

                    // Simulate work
                    await Task.Delay(TimeSpan.FromSeconds(20)); // Simulated long task

                    // Stop the renewal process and exit
                    cts.Cancel();
                    await renewalTask;
                    Console.WriteLine("🔓 Lock released!");
                }
                else
                {
                    Console.WriteLine("❌ Failed to acquire lock. Retrying...");
                    await Task.Delay(1000);
                }
            }
        }
    }

    /// <summary>
    /// Periodically tries to extend the lock before it expires.
    /// </summary>
    private static async Task RenewLockAsync(RedLockFactory redlockFactory, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            await Task.Delay(LockDuration - RenewBefore, cancellationToken); // Wait before expiry

            using (var redLock = await redlockFactory.CreateLockAsync(LockKey, LockDuration))
            {
                if (redLock.IsAcquired)
                {
                    Console.WriteLine("⏳ Lock extended!");
                }
                else
                {
                    Console.WriteLine("⚠️ Lock renewal failed! Another process may have acquired it.");
                    break;
                }
            }
        }
    }
}
