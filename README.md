https://github.com/dotnet/efcore/blob/main/src/EFCore/Extensions/EntityFrameworkQueryableExtensions.cs
 var supplierAsn = _commandContext.SupplierAsn!.Where(x => x.La14SourceFileName == la14SourceFileName && x.MlpNumber == palletNumber && x.LotCode == lotCode && !x.IsDeleted && x.TenantId == tenantId);
                await supplierAsn.ExecuteUpdateAsync<SupplierAsn>(_commandContext!, builder, tableName!);
