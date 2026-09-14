CREATE TYPE "ProgramStatus" AS ENUM ('DRAFT','ACTIVE','PAUSED','ENDED');
CREATE TYPE "PartnerStatus" AS ENUM ('PENDING','ACTIVE','SUSPENDED','REJECTED');
CREATE TYPE "CommissionStatus" AS ENUM ('PENDING','APPROVED','PAID','REVERSED');
CREATE TYPE "CommissionType" AS ENUM ('REFERRAL','AFFILIATE','CASHBACK','CREATOR');
CREATE TYPE "EarningEventType" AS ENUM ('CLICK','SIGNUP','PURCHASE','CREATOR_APPROVED');
CREATE TYPE "PayoutRequestStatus" AS ENUM ('REQUESTED','PROCESSING','PAID','REJECTED');

CREATE TABLE "EarningProfile" (
  "id" TEXT NOT NULL, "userId" TEXT NOT NULL, "referralCode" TEXT NOT NULL,
  "totalEarned" DECIMAL(14,2) NOT NULL DEFAULT 0, "pendingBalance" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "availableBalance" DECIMAL(14,2) NOT NULL DEFAULT 0, "clicks" INTEGER NOT NULL DEFAULT 0,
  "conversions" INTEGER NOT NULL DEFAULT 0, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL, CONSTRAINT "EarningProfile_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "EarningProfile_userId_key" UNIQUE ("userId"), CONSTRAINT "EarningProfile_referralCode_key" UNIQUE ("referralCode"),
  CONSTRAINT "EarningProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "AffiliateProgram" (
  "id" TEXT NOT NULL, "shopId" TEXT NOT NULL, "name" TEXT NOT NULL, "description" TEXT,
  "status" "ProgramStatus" NOT NULL DEFAULT 'DRAFT', "commissionRate" DOUBLE PRECISION NOT NULL DEFAULT 5,
  "fixedReward" DECIMAL(14,2), "currency" TEXT NOT NULL DEFAULT 'GHS', "cookieDays" INTEGER NOT NULL DEFAULT 30,
  "maxReward" DECIMAL(14,2), "cashbackRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "AffiliateProgram_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "AffiliateProgram_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "AffiliateProgram_shopId_status_idx" ON "AffiliateProgram"("shopId","status");

CREATE TABLE "AffiliatePartner" (
  "id" TEXT NOT NULL, "programId" TEXT NOT NULL, "userId" TEXT NOT NULL, "status" "PartnerStatus" NOT NULL DEFAULT 'PENDING',
  "code" TEXT NOT NULL, "clicks" INTEGER NOT NULL DEFAULT 0, "conversions" INTEGER NOT NULL DEFAULT 0,
  "earned" DECIMAL(14,2) NOT NULL DEFAULT 0, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AffiliatePartner_pkey" PRIMARY KEY ("id"), CONSTRAINT "AffiliatePartner_code_key" UNIQUE ("code"),
  CONSTRAINT "AffiliatePartner_programId_userId_key" UNIQUE ("programId","userId"),
  CONSTRAINT "AffiliatePartner_programId_fkey" FOREIGN KEY ("programId") REFERENCES "AffiliateProgram"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "AffiliatePartner_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "AffiliatePartner_programId_status_idx" ON "AffiliatePartner"("programId","status");

CREATE TABLE "ReferralClick" (
  "id" TEXT NOT NULL, "programId" TEXT, "partnerId" TEXT, "earningProfileId" TEXT, "code" TEXT NOT NULL,
  "ipHash" TEXT, "userAgent" TEXT, "landingPath" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ReferralClick_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ReferralClick_programId_fkey" FOREIGN KEY ("programId") REFERENCES "AffiliateProgram"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "ReferralClick_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "AffiliatePartner"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "ReferralClick_earningProfileId_fkey" FOREIGN KEY ("earningProfileId") REFERENCES "EarningProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX "ReferralClick_code_createdAt_idx" ON "ReferralClick"("code","createdAt");
CREATE INDEX "ReferralClick_programId_createdAt_idx" ON "ReferralClick"("programId","createdAt");

CREATE TABLE "ReferralConversion" (
  "id" TEXT NOT NULL, "orderId" TEXT NOT NULL, "partnerId" TEXT, "programId" TEXT, "code" TEXT,
  "orderValue" DECIMAL(14,2) NOT NULL, "attributedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ReferralConversion_pkey" PRIMARY KEY ("id"), CONSTRAINT "ReferralConversion_orderId_key" UNIQUE ("orderId"),
  CONSTRAINT "ReferralConversion_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ReferralConversion_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "AffiliatePartner"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "ReferralConversion_programId_fkey" FOREIGN KEY ("programId") REFERENCES "AffiliateProgram"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE "Commission" (
  "id" TEXT NOT NULL, "earningProfileId" TEXT NOT NULL, "partnerId" TEXT, "programId" TEXT, "conversionId" TEXT,
  "type" "CommissionType" NOT NULL, "status" "CommissionStatus" NOT NULL DEFAULT 'PENDING', "amount" DECIMAL(14,2) NOT NULL,
  "platformFee" DECIMAL(14,2) NOT NULL DEFAULT 0, "cashback" DECIMAL(14,2) NOT NULL DEFAULT 0, "currency" TEXT NOT NULL DEFAULT 'GHS',
  "description" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "approvedAt" TIMESTAMP(3), "paidAt" TIMESTAMP(3),
  CONSTRAINT "Commission_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Commission_earningProfileId_fkey" FOREIGN KEY ("earningProfileId") REFERENCES "EarningProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "Commission_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "AffiliatePartner"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "Commission_programId_fkey" FOREIGN KEY ("programId") REFERENCES "AffiliateProgram"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "Commission_conversionId_fkey" FOREIGN KEY ("conversionId") REFERENCES "ReferralConversion"("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX "Commission_earningProfileId_status_createdAt_idx" ON "Commission"("earningProfileId","status","createdAt");
CREATE INDEX "Commission_programId_status_idx" ON "Commission"("programId","status");

CREATE TABLE "EarningEvent" (
  "id" TEXT NOT NULL, "userId" TEXT, "type" "EarningEventType" NOT NULL, "referenceId" TEXT, "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT "EarningEvent_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "EarningEvent_type_createdAt_idx" ON "EarningEvent"("type","createdAt");
CREATE INDEX "EarningEvent_referenceId_idx" ON "EarningEvent"("referenceId");

CREATE TABLE "EarningPayoutRequest" (
  "id" TEXT NOT NULL, "earningProfileId" TEXT NOT NULL, "userId" TEXT NOT NULL, "amount" DECIMAL(14,2) NOT NULL,
  "status" "PayoutRequestStatus" NOT NULL DEFAULT 'REQUESTED', "paystackTransferCode" TEXT, "payoutMethod" TEXT NOT NULL DEFAULT 'PAYSTACK',
  "destination" TEXT, "note" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "processedAt" TIMESTAMP(3),
  CONSTRAINT "EarningPayoutRequest_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "EarningPayoutRequest_earningProfileId_fkey" FOREIGN KEY ("earningProfileId") REFERENCES "EarningProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "EarningPayoutRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "EarningPayoutRequest_userId_status_idx" ON "EarningPayoutRequest"("userId","status");
CREATE INDEX "EarningPayoutRequest_earningProfileId_status_idx" ON "EarningPayoutRequest"("earningProfileId","status");

CREATE TABLE "CreatorCampaign" (
  "id" TEXT NOT NULL, "shopId" TEXT NOT NULL, "programId" TEXT, "title" TEXT NOT NULL, "description" TEXT NOT NULL,
  "deliverable" TEXT, "budget" DECIMAL(14,2) NOT NULL, "rewardPerCreator" DECIMAL(14,2) NOT NULL, "maxCreators" INTEGER NOT NULL DEFAULT 10,
  "status" "ProgramStatus" NOT NULL DEFAULT 'DRAFT', "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CreatorCampaign_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "CreatorCampaign_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CreatorCampaign_programId_fkey" FOREIGN KEY ("programId") REFERENCES "AffiliateProgram"("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX "CreatorCampaign_shopId_status_idx" ON "CreatorCampaign"("shopId","status");

CREATE TABLE "CreatorApplication" (
  "id" TEXT NOT NULL, "campaignId" TEXT NOT NULL, "creatorId" TEXT NOT NULL, "status" "PartnerStatus" NOT NULL DEFAULT 'PENDING',
  "proofUrl" TEXT, "note" TEXT, "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "reviewedAt" TIMESTAMP(3),
  CONSTRAINT "CreatorApplication_pkey" PRIMARY KEY ("id"), CONSTRAINT "CreatorApplication_campaignId_creatorId_key" UNIQUE ("campaignId","creatorId"),
  CONSTRAINT "CreatorApplication_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "CreatorCampaign"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CreatorApplication_creatorId_fkey" FOREIGN KEY ("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "CreatorApplication_creatorId_status_idx" ON "CreatorApplication"("creatorId","status");
