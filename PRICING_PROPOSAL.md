# EKS Setup - What It'll Cost You

After doing this for 17 years, I've learned that being upfront about pricing saves everyone time. Here's what you're looking at for a complete EKS setup on your AWS account.

**Bottom line**: $45k-$55k gets you a production-ready setup in 4-5 weeks. Or we can do it hourly at $150-$200/hr if you prefer that model.

---

## How I Price This

I've done enough of these to know what they actually take. The fixed price option is what I recommend - you know exactly what you're paying, and I take the risk if things take longer than expected. I've seen too many projects go sideways with hourly billing where scope creeps and everyone's unhappy.

**Fixed Price**: $45,000 - $55,000  
This covers everything from infrastructure to monitoring. The range depends on a few things - how complex your apps are, if you need multi-region, compliance requirements, that kind of stuff. We'll nail it down after I see what you're working with.

**Hourly**: $150-$200/hour  
If you want to go this route, expect 225-285 hours total. I bill weekly, show you exactly what I worked on. Some clients prefer this, especially if they're not sure about scope yet.

**Phased**: Pay as we go  
Start with infrastructure ($7,500-$9,000), see how it goes, then add phases. I'm flexible - sometimes it makes sense to prove the relationship works first.

---

## What You're Actually Getting

Let me break down what each phase costs and why:

### Phase 1: Infrastructure (Terraform) - $7,500-$9,000
This is the foundation. VPC, EKS cluster, networking, IAM setup. I'll use Terraform because you'll want to version control this and be able to recreate it. I've seen too many "works on my machine" setups that can't be reproduced.

Takes about a week. The cluster itself takes 15-20 minutes to spin up, but getting all the pieces right - subnets, security groups, IRSA setup - that's where the time goes. I'll give you the code, show you how to run it, document the variables.

### Phase 2: Application Development - $6,000-$8,000
I'm assuming you have 2-3 services to containerize. If you've got more, we'll adjust. I'll Dockerize them, add proper health checks (learned the hard way why these matter), set up logging that actually makes sense.

This is where I see a lot of people cut corners and regret it later. Proper health checks, structured logging, graceful shutdowns - these things seem optional until 2am when something's broken and you can't figure out why.

### Phase 3: Helm Charts - $3,500-$4,500
Kubernetes manifests wrapped in Helm. I'll template it properly so you can deploy to dev/staging/prod with different configs. Ingress setup, resource limits (I'll help you figure out what you actually need), all that.

Takes 2-3 days. Most of the time is getting the values files right and testing upgrades/rollbacks. You want to know rollbacks work before you need them.

### Phase 4: CI/CD (GitHub Actions) - $4,500-$6,000
Automated builds, tests, image pushes to ECR, Helm chart updates. I'll set it up so a commit triggers the whole pipeline. Environment-specific workflows - dev auto-deploys, prod needs approval.

I've built enough of these to know the gotchas. Caching Docker layers, handling secrets properly, making sure failed builds don't deploy. The basics are straightforward, but the details matter.

### Phase 5: ArgoCD - $3,500-$4,500
GitOps setup. ArgoCD watches your Helm charts in Git and syncs to the cluster. Once this is working, deployments become trivial. I'll configure sync policies, health checks, all that.

Takes 2-3 days. The first sync is always slow, but after that it's pretty smooth. I'll show you the UI, how to do manual syncs if needed, how to rollback.

### Phase 6: Testing - $2,500-$3,500
End-to-end testing. Make sure the whole pipeline works, deployments actually deploy, rollbacks work, services talk to each other. I'll break things intentionally to test recovery.

This is where I catch the issues that would bite you in production. Worth every dollar.

### Phase 7: Monitoring - $3,500-$4,500
Prometheus + Grafana, or CloudWatch if you prefer. Logging setup (Fluent Bit to CloudWatch or Loki). Alerting rules for the things that actually matter.

I'll instrument your apps with metrics, set up dashboards you'll actually use. Too many monitoring setups collect everything and show nothing useful. I'll keep it practical.

### Phase 8: Security - $2,500-$3,500
Network policies, secrets management (AWS Secrets Manager), RBAC, image scanning in CI/CD. I'll start permissive and tighten gradually - too restrictive too early breaks things.

Security is important, but I've seen teams lock themselves out of their own systems by being too aggressive. We'll do it right, but we'll do it smart.

### Phase 9: Documentation - $2,000-$2,500
Architecture docs, runbooks, how to deploy, how to troubleshoot. I'll keep it current - outdated docs are worse than no docs.

Plus a knowledge transfer session where I walk you through everything, answer questions, show you the common issues and how to fix them.

### Phase 10: Optimization - $2,000-$2,500
Right-size your resources, optimize costs, tune performance. I'll look at what you're actually using vs what you're requesting, suggest changes.

This usually pays for itself in AWS savings within a few months.

---

## The AWS Bill (Separate)

You'll pay AWS directly for infrastructure. I don't mark this up - it's your account, your bill.

**Development environment**: Around $230/month
- EKS control plane: $73 (AWS charges this, not me)
- 3 small nodes: ~$90
- NAT gateway: ~$32
- Load balancer: ~$20
- Storage, logs, misc: ~$15

**Production**: Around $644/month
- Same control plane: $73
- 6 larger nodes across 3 AZs: ~$360
- 3 NAT gateways (one per AZ): ~$96
- Load balancer: ~$25
- Monitoring, logs: ~$50
- Misc: ~$40

**Total**: ~$874/month for dev + prod

These are estimates. Your actual costs depend on traffic, instance sizes, how much logging you keep, etc. I'll help you optimize this in Phase 10.

---

## Payment

**Fixed price**: 
- 30% to start (covers my time commitment)
- 40% when ArgoCD is working (mid-point milestone)
- 30% when everything's delivered and you're happy

**Hourly**: 
- Weekly invoices
- Net 15 terms
- I'll show you exactly what I worked on

I'm reasonable about payment terms if you need to adjust. Just talk to me.

---

## What's Included

You get all the code, configs, documentation. I'll hand over everything - Terraform, Helm charts, CI/CD workflows, all of it. It's yours.

30 days of support after delivery for bug fixes, questions, that kind of thing. After that, if you want ongoing support, we can talk about that separately.

Knowledge transfer session - usually 2-3 hours where I walk you through everything, show you how to operate it, answer questions. I'll record it if you want.

---

## What's Not Included

AWS costs - you pay AWS directly. I don't mark these up.

Application development beyond basic containerization. If you need me to build new features, that's separate.

Ongoing maintenance after 30 days. I'm happy to do it, but it's a separate engagement.

24/7 on-call. Available as add-on if you need it.

---

## Why This Price?

I've been doing Kubernetes and AWS work for 17 years. I've seen what happens when this is done cheap - corners get cut, things break at 2am, it costs more to fix than it would have to do right the first time.

Market rate for someone with this experience is $150-$200/hour. At 225-285 hours, that's $33,750-$57,000. The fixed price is in that range, but you get budget certainty and I take the risk if it takes longer.

Compared to hiring 2-3 engineers for 6 months to figure this out? You're saving $150k+ and 4-5 months. Plus they'll make mistakes I've already made and learned from.

---

## Cost Comparison: US vs Indian Development

I get asked about this a lot. Let me be honest about the numbers.

| Factor | Indian Team | Me (US-Based) |
|--------|-------------|---------------|
| **Hourly Rate** | $30-$60/hour (senior) | $150-$200/hour |
| **Team Size** | 2-3 developers | 1 (me) |
| **Upfront Cost** | $20,000-$40,000 | $45,000-$55,000 |
| **Realistic Cost** | $30,000-$50,000 (with overhead) | $45,000-$55,000 (fixed) |
| **Timeline** | 6-8 weeks (often 8-10) | 4-5 weeks |
| **Time Zone** | 10-12 hour difference | Same time zone |
| **Communication** | Async, language barriers | Direct, native English |
| **Management Overhead** | High (you manage them) | Low (I'm self-managed) |
| **Experience** | Varies (finding right team) | 17 years EKS/AWS |
| **Quality Risk** | Higher (more rework) | Lower (proven track record) |

**Indian Development Team**:
- Senior Kubernetes/AWS engineer: $30-$60/hour
- Mid-level: $20-$40/hour
- Junior: $10-$25/hour

For a team of 2-3 developers, you're looking at:
- **Cost**: $20,000-$40,000 (lower hourly rates)
- **Timeline**: 6-8 weeks (often longer due to learning curve, time zone, communication overhead)
- **Total project**: Potentially $30,000-$50,000 when you factor in delays and rework

**Why the difference?**

**Time zones**: 10-12 hour difference means async communication, slower feedback loops, meetings at odd hours. What takes 1 day with me takes 2-3 days with offshore.

**Communication**: I'm native English, same time zone, can jump on a call when you need me. No language barriers, no "let me check with the team and get back to you tomorrow."

**Experience**: 17 years doing this specific work. I've seen the gotchas, know the shortcuts, understand what actually matters vs what looks good in a proposal.

**Quality**: I've fixed enough offshore work to know the difference. Not that Indian developers are bad - there are excellent ones. But finding the right team, managing them, dealing with turnover, quality control - that's all extra cost and time.

**Hidden costs**: Project management overhead, rework from miscommunication, delays from time zone issues, quality issues that show up later. These add up.

**Bottom line**: You might save $10k-$20k upfront with Indian developers, but you'll spend more time managing it, deal with longer timelines, and potentially pay more in the long run when things need fixing.

If budget is tight, I get it. But if you can swing it, the US-based option usually pays for itself in speed, quality, and less headache.

---

## Timeline

**Week 1-2**: Infrastructure and application work. You'll have a working cluster by end of week 1.

**Week 3**: Helm charts and CI/CD. By end of week 3, code commits trigger deployments.

**Week 4**: ArgoCD and testing. GitOps is working, everything's tested.

**Week 5**: Monitoring, security, docs, optimization. Polish and handoff.

I can go faster if you need it, but rushing usually means cutting corners. I'd rather do it right.

---

## Common Questions

**Can we start with just infrastructure?**  
Sure. Phase 1 standalone is $7,500-$9,000. We can add phases as you're ready.

**What if requirements change?**  
We'll handle it with a change order. Fixed price covers what we agree on upfront. If you want to add stuff, we'll price it separately.

**Do you do ongoing support?**  
30 days is included. After that, I'm happy to do it - usually $2k-$3k/month depending on what you need. Some clients want me on retainer, others just call when they need help.

**What if we already have some of this?**  
Great, we'll adjust. If you've got infrastructure, Phase 1 gets cheaper. If you've got containerized apps, Phase 2 gets cheaper. I'll credit you for work already done.

**Can you do it faster?**  
Maybe. Depends on what you're willing to cut. I can rush it, but it'll cost more (1.5x rate) and I'd rather not. These things have a natural pace.

**What about Indian developers? They're cheaper.**  
They are. $30-$60/hour vs my $150-$200/hour. But you're looking at 6-8 weeks instead of 4-5, time zone issues, communication overhead, and often more rework. I've fixed enough offshore projects to know the real cost. If budget is the constraint, we can talk about phasing or reducing scope. But the cheapest option isn't always the best value.

**What if something goes wrong?**  
I fix it. That's what the 30-day support is for. If it's my mistake, I fix it on my time. If it's something outside scope, we'll figure it out.

---

## Next Steps

If this works for you, let's talk. I'll want to understand:
- What you're trying to accomplish
- What you already have
- Timeline expectations
- Any specific requirements (compliance, multi-region, etc.)

Then I'll give you a firm number and we can get started.

**This quote is good for 30 days.** After that, I'll refresh it based on current availability.

---

*I've been doing this long enough to know that the best projects are the ones where expectations are clear upfront. If you have questions, ask. If something doesn't make sense, let's talk about it. I'd rather have that conversation now than later.*
