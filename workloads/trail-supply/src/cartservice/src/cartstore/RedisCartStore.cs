// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Linq;
using System.Threading.Tasks;
using Grpc.Core;
using Microsoft.Extensions.Caching.Distributed;
using Google.Protobuf;

namespace cartservice.cartstore
{
    public class RedisCartStore : ICartStore
    {
        private readonly IDistributedCache _cache;

        public RedisCartStore(IDistributedCache cache)
        {
            _cache = cache;
        }

        public async Task AddItemAsync(string userId, string productId, int quantity)
        {
            Telemetry.Log("storage.diagnostic","storage");

            try
            {
                Hipstershop.Cart cart;
                var value = await Telemetry.Cache("read",()=>_cache.GetAsync(userId));
                if (value == null)
                {
                    cart = new Hipstershop.Cart();
                    cart.UserId = userId;
                    cart.Items.Add(new Hipstershop.CartItem { ProductId = productId, Quantity = quantity });
                }
                else
                {
                    cart = Hipstershop.Cart.Parser.ParseFrom(value);
                    var existingItem = cart.Items.SingleOrDefault(i => i.ProductId == productId);
                    if (existingItem == null)
                    {
                        cart.Items.Add(new Hipstershop.CartItem { ProductId = productId, Quantity = quantity });
                    }
                    else
                    {
                        existingItem.Quantity += quantity;
                    }
                }
                await Telemetry.Cache("write",()=>_cache.SetAsync(userId, cart.ToByteArray()));
            }
            catch (Exception)
            {
                throw new RpcException(new Status(StatusCode.FailedPrecondition, "Cannot access cart storage"));
            }
        }

        public async Task EmptyCartAsync(string userId)
        {
            Telemetry.Log("storage.diagnostic","storage");

            try
            {
                var cart = new Hipstershop.Cart();
                await Telemetry.Cache("write",()=>_cache.SetAsync(userId, cart.ToByteArray()));
            }
            catch (Exception)
            {
                throw new RpcException(new Status(StatusCode.FailedPrecondition, "Cannot access cart storage"));
            }
        }

        public async Task<Hipstershop.Cart> GetCartAsync(string userId)
        {
            Telemetry.Log("storage.diagnostic","storage");

            try
            {
                // Access the cart from the cache
                var value = await Telemetry.Cache("read",()=>_cache.GetAsync(userId));

                if (value != null)
                {
                    return Hipstershop.Cart.Parser.ParseFrom(value);
                }

                // We decided to return empty cart in cases when user wasn't in the cache before
                return new Hipstershop.Cart();
            }
            catch (Exception)
            {
                throw new RpcException(new Status(StatusCode.FailedPrecondition, "Cannot access cart storage"));
            }
        }

        public bool Ping()
        {
            try
            {
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }
    }
}
